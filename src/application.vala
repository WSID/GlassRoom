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

        public Gst.Pipeline pipeline {get; }

        construct {
            add_option_group (Gst.init_get_option_group());

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

            Gst.Element source = Gst.ElementFactory.make ("videotestsrc", "source");
            Gst.Element sink = Gst.ElementFactory.make ("autovideosink", "sink");

            _pipeline.add (source);
            _pipeline.add (sink);
            source.link (sink);
        }

        public override void activate () {
            base.activate ();
            var window = active_window ?? new GlassRoom.Window (this);
            window.present ();

            _pipeline.set_state (Gst.State.PLAYING);
        }
    }
}
