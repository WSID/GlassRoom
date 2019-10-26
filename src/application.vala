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

        private bool _recording = false;
        private bool _pausing = false;

        public Gst.Pipeline pipeline {get; }
        public GLib.ListModel sources {get { return _sources; } }

        private Gst.Element tee;
        private Gst.Element encode_bin;
        private Gst.Pad? tee_encode_bin_src;
        private Gst.Pad? tee_encode_bin_sink;

        private Gst.Element file_sink;
        private Gst.Element view_queue;
        private Gst.Element view_sink;

        private delegate void SimpleCallback ();

        // Overall Pipeline

        //                                            --> queue --> gtksink (preview)
        //                                           |
        // [sources: GlassRoom.SrcBin 0..] --> Tee -----> encodebin --> filesink

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


        private Gst.ClockTime pause_start;
        private Gst.ClockTime pause_end;

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

        private Gst.ClockTime recording_duration_acc;
        private Gst.ClockTime record_resume_time;
        public Gst.ClockTime recording_duration {
            get {
                if (! recording) return 0;

                Gst.ClockTime recording_duration_current = 0;

                if (! pausing) {
                    recording_duration_current =
                        _pipeline.get_clock().get_time() -
                        record_resume_time;
                }

                return recording_duration_acc + recording_duration_current;
            }
        }


        construct {
            add_option_group (Gst.init_get_option_group());

            _sources = new GLib.ListStore (typeof (GlassRoom.SrcBin));
        }

        public Application () {
            Object (application_id: "standalone.glassroom.GlassRoom",
                    flags: ApplicationFlags.FLAGS_NONE);
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

            tee = Gst.ElementFactory.make ("tee", "tee");
            encode_bin = Gst.ElementFactory.make ("encodebin", "encode-bin");
            file_sink = Gst.ElementFactory.make ("filesink", "file-sink");
            view_queue = Gst.ElementFactory.make ("queue", "view-queue");

            // TEMP: Prepare profile for recording.
            Gst.PbUtils.EncodingContainerProfile profile = new Gst.PbUtils.EncodingContainerProfile (
                "Ogg audio/video",
                "Standard OGG/THEORA/VORBIS",
                Gst.Caps.from_string ("application/ogg"), null);

            profile.add_profile (new Gst.PbUtils.EncodingVideoProfile (
                Gst.Caps.from_string ("video/x-theora"), null, null, 0));


            // Setup element properties.
            encode_bin.set ("profile", profile);
            file_sink.set ("location", "/home/wissle/myvid.ogg");

            // linking elemets.
            _pipeline.add_many (tee, view_queue, encode_bin);

            tee.get_request_pad ("src_%u").link (view_queue.get_static_pad ("sink"));


            // TODO: This is priliminary connection.
            //       1. Assemble pipeline at right position.
            //       2. Replace test elements into right elements, when ready.

            {
                // Variables in this section is bound to closure.
                Gst.Element? source = null;
                _sources.items_changed.connect ((model, position, n_remove, n_add) => {
                    // Only picks first source in the model.

                    // Remove currently connected source.
                    if (source != null) {
                        source.set_state (Gst.State.NULL);
                        source.unlink (tee);
                        _pipeline.remove (source);
                    }

                    source = (Gst.Element) model.get_item(0);
                    if (source != null) {
                        _pipeline.add (source);
                        source.link (tee);
                        source.sync_state_with_parent();
                        source.set_state (Gst.State.PLAYING);
                    }
                });
            }
        }

        public override void activate () {
            base.activate ();
            var window = active_window;

            if (window == null) {
                var grwindow = new GlassRoom.Window (this);

                view_sink = grwindow.view_sink;
                _pipeline.add (view_sink);
                view_queue.link (view_sink);

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
            _sources.append (src_bin);
            return src_bin;
        }

        public bool remove_source (GlassRoom.SrcBin src_bin) {
            uint i = 0;
            GlassRoom.SrcBin? item = (GlassRoom.SrcBin?)_sources.get_item (i);

            while (item != null) {
                if (item == src_bin) {
                    _sources.remove (i);
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
                    _sources.remove (i - 1);
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
            if (path == null) {
                path = "/home/wissle/myvid.ogg";
            }

            file_sink.set ("location", path);

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

                recording_duration_acc = 0;
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
                        pause_start = tee.get_clock().get_time();
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
                    pause_end = tee.get_clock().get_time();
                    Gst.ClockTime pause_duration = pause_end - pause_start;
                    tee_encode_bin_sink.offset = tee_encode_bin_sink.offset - (int64)pause_duration;

                    link_recorder ();

                    file_sink.sync_state_with_parent ();

                    _pausing = false;
                    notify_property ("pausing");
                }
                return was_pausing;
            }
            return false;
        }




        // Pipeline Manipulation.

        private void link_recorder () {
            tee_encode_bin_src = tee.get_request_pad ("src_%u");
            tee_encode_bin_src.link (tee_encode_bin_sink);

            record_resume_time = _pipeline.get_clock().get_time();
        }


        private void unlink_recorder (owned SimpleCallback callback) {
            if (tee_encode_bin_src != null) {
                tee_encode_bin_src.add_probe (
                    Gst.PadProbeType.BLOCK_DOWNSTREAM,
                    (pad, info) => {
                        pad.unlink (tee_encode_bin_sink);
                        tee.release_request_pad (pad);

                        recording_duration_acc +=
                            _pipeline.get_clock().get_time() - record_resume_time;

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


        private void activate_remove_source (Variant? variant) {
            string src_bin = (string) variant;
            remove_source_by_name (src_bin);
        }
    }
}
