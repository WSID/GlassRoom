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

        public Gst.Pipeline pipeline {get; }
        public GLib.ListModel sources {get { return _sources; } }

        private Gst.Element tee;
        private Gst.Element encode_bin;
        private Gst.Element file_sink;
        private Gst.Element view_queue;
        private Gst.Element view_sink;

        // Overall Pipeline

        //                                            --> queue --> gtksink (preview)
        //                                           |
        // [sources: GlassRoom.SrcBin 0..] --> Tee -----> encodebin --> filesink



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


            _pipeline = new Gst.Pipeline ("GlassRoom pipeline");

            tee = Gst.ElementFactory.make ("tee", "tee");
            encode_bin = Gst.ElementFactory.make ("encodebin", "encode-bin");
            file_sink = Gst.ElementFactory.make ("filesink", "file-sink");
            view_queue = Gst.ElementFactory.make ("queue", "view-queue");

            Gst.PbUtils.EncodingContainerProfile profile = new Gst.PbUtils.EncodingContainerProfile (
                "Ogg audio/video",
                "Standard OGG/THEORA/VORBIS",
                Gst.Caps.from_string ("application/ogg"), null);

            profile.add_profile (new Gst.PbUtils.EncodingVideoProfile (
                Gst.Caps.from_string ("video/x-theora"), null, null, 0));


            encode_bin.set ("profile", profile);
            file_sink.set ("location", "myvid.ogg");
            _pipeline.add_many (tee, view_queue, encode_bin, file_sink);
            encode_bin.link (file_sink);
            tee.get_request_pad ("src_%u").link (encode_bin.get_request_pad ("video_%u"));
            tee.get_request_pad ("src_%u").link (view_queue.get_static_pad ("sink"));

            tee.set_state (Gst.State.PLAYING);
            view_queue.set_state (Gst.State.PLAYING);

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


        private void activate_remove_source (Variant? variant) {
            string src_bin = (string) variant;
            remove_source_by_name (src_bin);
        }
    }
}
