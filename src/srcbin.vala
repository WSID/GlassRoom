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

        private string? _source_factory_name;

        //private Gst.Base.Src? _source;
        private Gst.GhostPad pad;

        public string? source_factory_name {
            get {
                return _source_factory_name;
            }
            set {
                if (_source_factory_name == value)
                    return;

                if (_source != null) {
                    _source.set_state(Gst.State.NULL);

                    if (_queue != null) {
                        _source.unlink (_queue);
                    }
                    else {
                        pad.set_target (null);
                    }
                    remove (_source);
                    _source = null;
                }

                _source_factory_name = value;

                if (value == null) return;

                Gst.Element? element = Gst.ElementFactory.make (value, "source");

                if (element == null) {
                    warning ("Cannot make source for factory \"%s\"", _source_factory_name);
                    notify_property ("source");
                    return;
                }

                _source = element as Gst.Base.Src;
                if (_source == null) {
                    warning ("\"%s\" is not source", _source_factory_name);
                    notify_property ("source");
                    return;
                }

                add (_source);

                if (_queue != null) {
                    _source.link (_queue);
                }
                else {
                    pad.set_target (_source.get_static_pad ("src"));
                }
                _source.sync_state_with_parent();
                notify_property ("source");

            }
        }

        public bool use_buffering {
            get {
                return (_queue != null);
            }

            set {
                if ((_queue != null) && (!value)) {
                    if (_source != null) {
                        _source.set_state (Gst.State.NULL);
                        _queue.set_state (Gst.State.NULL);
                        _source.unlink (_queue);

                        pad.set_target (_source.get_static_pad ("src"));
                        _source.sync_state_with_parent();
                    }

                    else {
                        pad.set_target (null);
                    }
                    remove (_queue);
                    _queue = null;
                }

                else if ((_queue == null) && (value)) {
                    _queue = Gst.ElementFactory.make ("queue", "queue");
                    add (_queue);

                    if (_source != null) {
                        _source.set_state (Gst.State.NULL);
                        pad.set_target (_queue.get_static_pad ("src"));

                        _source.link (_queue);
                        _source.sync_state_with_parent();
                    }
                    _queue.sync_state_with_parent();
                }

                else {
                    return;
                }

                notify_property ("queue");
            }
        }

        public Gst.Base.Src? source { get; }

        public Gst.Element? queue { get; }

        construct {
            pad = new Gst.GhostPad.no_target ("src", Gst.PadDirection.SRC);
            add_pad (pad);
        }

        public SrcBin (string name, string? factory_name = null) {
            Object (name: name, source_factory_name: factory_name);
        }
    }
}
