/* application.vala
 *
 * Copyright 2019 Wissle
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE X CONSORTIUM BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name(s) of the above copyright
 * holders shall not be used in advertising or otherwise to promote the sale,
 * use or other dealings in this Software without prior written
 * authorization.
 */

namespace GlassRoom {
    public class Application: Gtk.Application {
        private GLib.ListStore _sources;

        // Recording status.
        private bool _recording = false;
        private bool _pausing = false;

        private Gst.ClockTime record_in_time;
        private Gst.ClockTime record_out_time;
        private Gst.ClockTime record_duration_acc;

        // Pipeline.
        public Gst.Pipeline pipeline {get; }
        public GLib.ListModel sources {get { return _sources; } }

        private Gst.Element compositor;
        private Gst.Element caps_filter;
        private Gst.Element tee;
        private Gst.Element encode_bin;
        private Gst.Pad? tee_encode_bin_src;
        private Gst.Pad? tee_encode_bin_sink;

        private Gst.Element file_sink;
        private Gst.Element view_queue;
        private Gst.Element view_sink;


        private delegate void SimpleCallback ();

        /**
         * Whether this is recording or not.
         *
         * Setting this property starts, or stops recording.
         */
        public bool recording {
            get {
                return _recording;
            }
            set {
                if ((_recording) && (!value)) stop_record();
                else if ((!_recording) && (value)) start_record();
            }
        }

        /**
         * Whether this is pausing the recording or not.
         *
         * This is always false, when not recording.
         *
         * Setting this property pauses, or unpauses on-going recording.
         * No effect when not recording.
         */
        public bool pausing {
            get {
                return _recording && _pausing;
            }
            set {
                if (_recording) {
                    if ((!_pausing) && (value)) pause_record ();
                    else if ((_pausing) && (!value)) unpause_record ();
                }
            }
        }

        public Gst.ClockTime record_duration {
            get {
                if (! recording) return 0;

                Gst.ClockTime record_duration_current = 0;

                if (! pausing) {
                    record_duration_current =
                        _pipeline.get_clock().get_time() -
                        record_in_time;
                }

                return record_duration_acc + record_duration_current;
            }
        }

        public string record_file {
            get {
                unowned string file;
                file_sink.get ("location", out file);
                return file;
            }
        }


        // File options

        public GLib.File file_base_path {get; set;}
        public string    file_name {get; set;}

        // Encoding Profiles

        private Gst.PbUtils.EncodingContainerProfile _encoding_profile;
        public Gst.PbUtils.EncodingContainerProfile encoding_profile {
            get {
                return _encoding_profile;
            }
            set {
                _encoding_profile = value;
                encode_bin = Gst.ElementFactory.make ("encodebin", "encode-bin");
                encode_bin.set ("profile", value);
            }
        }

        construct {
            add_option_group (Gst.init_get_option_group());

            _sources = new GLib.ListStore (typeof (GlassRoom.SrcBin));

            string base_path_str = GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS);
            file_base_path = GLib.File.new_for_path (base_path_str);
            file_name = "video-%c.ogg";
        }

        public Application () {
            Object (application_id: "standalone.glassroom.GlassRoom",
                    flags: ApplicationFlags.FLAGS_NONE);
        }

        /**
         * Format file name to record.
         *
         * Signal handlers are expected to modify `file_name`.
         *
         * @param file_name A file name to format.
         */
        public virtual signal void format_file_name (ref string file_name) {
            GLib.DateTime time = new GLib.DateTime.now ();

            file_name = time.format (file_name);
        }

        public override void startup () {
            base.startup();

            GLib.SimpleAction action_remove_source = new GLib.SimpleAction ("remove-source", VariantType.STRING);
            action_remove_source.activate.connect (activate_remove_source);
            add_action (action_remove_source);

            add_action (new GLib.PropertyAction ("record", this, "recording"));
            add_action (new GLib.PropertyAction ("pause", this, "pausing"));


            // Make Elements for pipeline.
            _pipeline = new Gst.Pipeline ("GlassRoom pipeline");
            _pipeline.message_forward = true;

            compositor = Gst.ElementFactory.make ("compositor", "compositor");
            caps_filter = Gst.ElementFactory.make ("capsfilter", "caps-filter");
            tee = Gst.ElementFactory.make ("tee", "tee");
            encode_bin = Gst.ElementFactory.make ("encodebin", "encode-bin");
            file_sink = Gst.ElementFactory.make ("filesink", "file-sink");

            // TEMP: Prepare profile for recording.
            _encoding_profile = new Gst.PbUtils.EncodingContainerProfile (
                "Ogg audio/video",
                "Standard OGG/THEORA/VORBIS",
                Gst.Caps.from_string ("application/ogg"), null);


            Gst.Caps video_format =
                new Gst.Caps.simple ("video/x-raw",
                    "width", typeof (int), 1920,
                    "height", typeof (int), 1080,
                    "framerate", typeof (Gst.Fraction), 60, 1);

            set_video_format (video_format);

            _encoding_profile.add_profile (new Gst.PbUtils.EncodingVideoProfile (
                new Gst.Caps.simple ("video/x-theora", "width", typeof (int), 1920, "height", typeof (int), 1080, "framerate", typeof (Gst.Fraction), 60, 1), null, null, 0));


            // Setup element properties.
            encode_bin.set ("profile", _encoding_profile);
            file_sink.set ("location", "/home/wissle/myvid.ogg");

            // linking elemets.
            _pipeline.add_many (compositor, caps_filter, tee);

            compositor.link (caps_filter);
            caps_filter.link (tee);
        }

        public override void activate () {
            base.activate ();
            var window = active_window;

            if (window == null) {
                var grwindow = new GlassRoom.Window (this);

                view_sink = grwindow.view_sink;
                _pipeline.add (view_sink);
                //view_queue.link (view_sink);
                tee.get_request_pad ("src_%u").link (view_sink.get_static_pad ("sink"));

                window = grwindow;
            }
            window.present ();
            _pipeline.set_state (Gst.State.PLAYING);
        }

        public GlassRoom.SrcBin add_source () {
            int index = 1;
            string name = "Source #%d".printf (index);

            while (get_source_by_name(name) != null) {
                index++;
                name = "Source #%d".printf (index);
            }

            GlassRoom.SrcBin src_bin = new GlassRoom.SrcBin (name, "videotestsrc");
            _pipeline.add (src_bin);

            Gst.Pad src_pad = src_bin.get_static_pad ("src");
            Gst.Pad sink_pad = compositor.get_request_pad ("sink_%u");

            src_pad.link (sink_pad);

            _sources.append (src_bin);
            src_bin.sync_state_with_parent();
            return src_bin;
        }

        public bool remove_source (GlassRoom.SrcBin src_bin) {
            uint i = 0;
            GlassRoom.SrcBin? item = (GlassRoom.SrcBin?)_sources.get_item (i);

            while (item != null) {
                if (item == src_bin) {
                    remove_source_internal (i, item);
                    return true;
                }

                i++;
                item = (GlassRoom.SrcBin?)_sources.get_item (i);
            }
            return false;
        }

        public bool remove_source_by_name (string src_bin) {
            uint i = 0;
            GlassRoom.SrcBin? item = (GlassRoom.SrcBin?)_sources.get_item (i);

            while (item != null) {
                if (item.get_name () == src_bin) {
                    remove_source_internal (i - 1, item);
                    return true;
                }

                i++;
                item = (GlassRoom.SrcBin?)_sources.get_item (i);
            }
            return false;
        }

        public GlassRoom.SrcBin? get_source_by_name (string src_bin) {
            uint i = 0;
            GlassRoom.SrcBin? item = (GlassRoom.SrcBin?)_sources.get_item (i);

            while (item != null) {
                if (item.get_name () == src_bin) {
                    return item;
                }

                i++;
                item = (GlassRoom.SrcBin?)_sources.get_item (i);
            }
            return null;
        }


        // Public Pipeline manipulation.

        /**
         * Starts record with given path name.
         *
         * @param path Path to file, or null for preset generated name.
         *
         * @return Whether this was not recording.
         */
        public bool start_record (string? path = null) {
            string actual_path = path ?? make_file_name();

            GLib.File actual_file = GLib.File.new_for_path (actual_path);
            GLib.File actual_dir = actual_file.get_parent ();

            if (! actual_dir.query_exists ())
                actual_dir.make_directory_with_parents ();

            file_sink.set ("location", path ?? make_file_name());

            bool was_not_recording = ! _recording;
            if (was_not_recording) {
                // Add elements.
                _pipeline.add (encode_bin);
                _pipeline.add (file_sink);
                encode_bin.link (file_sink);

                tee_encode_bin_sink = encode_bin.get_request_pad ("video_%u");
                link_recorder ();

                encode_bin.sync_state_with_parent ();
                file_sink.sync_state_with_parent ();

                record_duration_acc = 0;
                _recording = true;
                notify_property ("recording");
            }

            return was_not_recording;
        }

        /**
         * Stops recording.
         *
         * @return Whether this was recording.
         */
        public bool stop_record () {
            bool was_recording = recording;

            if (was_recording) {
                if (_pausing) {
                    _pausing = false;
                    notify_property ("pausing");
                }

                unlink_recorder (() => {
                    _pipeline.get_bus().add_watch (0, (bus,message) => {

                        if ((message.src == file_sink) && (message.type == Gst.MessageType.STATE_CHANGED)) {

                            encode_bin.set_state (Gst.State.NULL);
                            file_sink.set_state (Gst.State.NULL);
                            encode_bin.release_request_pad (tee_encode_bin_sink);
                            tee_encode_bin_sink = null;

                            encode_bin.unlink (file_sink);
                            _pipeline.remove (encode_bin);
                            _pipeline.remove (file_sink);

                            return false;
                        }
                        return true;
                    });
                });

                _recording = false;
                notify_property ("recording");
            }

            return was_recording;
        }


        public bool pause_record () {
            if (_recording) {
                bool was_not_pausing = ! _pausing;

                if (was_not_pausing) {
                    unlink_recorder (() => {
                        file_sink.set_state (Gst.State.PAUSED);
                    });
                    _pausing = true;
                    notify_property ("pausing");
                }
                return was_not_pausing;
            }
            return false;
        }

        public bool unpause_record () {
            if (_recording) {
                bool was_pausing = _pausing;

                if (was_pausing) {
                    link_recorder ();
                    Gst.ClockTime pause_duration = record_in_time - record_out_time;
                    tee_encode_bin_sink.offset = tee_encode_bin_sink.offset - (int64)pause_duration;

                    file_sink.sync_state_with_parent ();

                    _pausing = false;
                    notify_property ("pausing");
                }
                return was_pausing;
            }
            return false;
        }


        public void set_video_format (Gst.Caps format) {
            caps_filter.set("caps", format);
        }




        // Pipeline Manipulation.

        private void remove_source_internal (uint index, GlassRoom.SrcBin src_bin) {
            Gst.Pad src_pad = src_bin.get_static_pad ("src");
            Gst.Pad sink_pad = src_pad.get_peer ();

            src_pad.unlink (sink_pad);
            compositor.release_request_pad (sink_pad);

            _sources.remove (index);
        }


        private void link_recorder () {
            tee_encode_bin_src = tee.get_request_pad ("src_%u");
            tee_encode_bin_src.link (tee_encode_bin_sink);

            record_in_time = _pipeline.get_clock().get_time();
        }


        private void unlink_recorder (owned SimpleCallback callback) {
            if (tee_encode_bin_src != null) {
                tee_encode_bin_src.add_probe (
                    Gst.PadProbeType.BLOCK_DOWNSTREAM,
                    (pad, info) => {
                        pad.unlink (tee_encode_bin_sink);
                        tee.release_request_pad (pad);

                        record_out_time = _pipeline.get_clock().get_time();
                        record_duration_acc += record_out_time - record_in_time;

                        callback();
                        return Gst.PadProbeReturn.REMOVE;
                    }
                );
                tee_encode_bin_src = null;
            }
            else {
                callback();
            }
        }

        private string make_file_name () {
            string base_path_string = file_base_path.get_path();
            string record_file_name = file_name;

            format_file_name (ref record_file_name);

            return base_path_string + "/" + record_file_name;
        }

        private void activate_remove_source (Variant? variant) {
            string src_bin = (string) variant;
            remove_source_by_name (src_bin);
        }
    }
}
