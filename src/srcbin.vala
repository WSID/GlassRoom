/* srcbin.vala
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
    /**
     * A Gst.Bin represents a source that GlassRoom manages.
     *
     * A single Gst.PushSrc cannot be used directly in GlassRoom. Someone wants
     * to apply filtering operation, like chroma-key. Sometimes, buffering is
     * required too.
     *
     * This will handle this.
     */
    public class SrcBin : Gst.Bin {
        public string source_factory_name {get; construct; }
        public Gst.Base.Src? source {get; }

        construct {
            Gst.Element? element = Gst.ElementFactory.make (source_factory_name, "source");
            if (element == null) {
                critical ("source make failed for factory \"%s\"", source_factory_name);
                return;
            }

            _source = element as Gst.Base.Src;

            if (_source != null) {
                add (_source);
                var src_pad = _source.get_static_pad ("src");
                var bin_pad = new Gst.GhostPad ("src", src_pad);
                add_pad (bin_pad);
            }
            else {
                critical ("\"%s\" is not source element.", source_factory_name);
            }
        }

        public SrcBin (string name, string factory_name) {
            Object (name: name, source_factory_name: factory_name);
        }
    }
}
