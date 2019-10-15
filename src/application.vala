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

        private Gst.Element sink;

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

            _pipeline = new Gst.Pipeline ("GlassRoom pipeline");

            // TODO: This is priliminary connection.
            //       1. Assemble pipeline at right position.
            //       2. Replace test elements into right elements, when ready.

            // Variables in this section is bound to closure.
            {
                Gst.Element? source = null;
                _sources.items_changed.connect ((model, position, n_remove, n_add) => {
                    // Only picks first source in the model.

                    // Remove currently connected source.
                    if (source != null) {
                        source.set_state (Gst.State.NULL);
                        source.unlink (sink);
                        _pipeline.remove (source);
                    }

                    source = (Gst.Element) model.get_item(0);
                    if (source != null) {
                        _pipeline.add (source);
                        source.link (sink);
                        source.sync_state_with_parent();
                    }
                });
            }
        }

        public override void activate () {
            base.activate ();
            var window = active_window;

            if (window == null) {
                var grwindow = new GlassRoom.Window (this);

                sink = grwindow.view_sink;
                _pipeline.add (sink);

                window = grwindow;
            }
            window.present ();

            _pipeline.set_state (Gst.State.PLAYING);
        }

        public void add_source () {
            _sources.append (new GlassRoom.SrcBin ("A Source", "videotestsrc"));
        }
    }
}
