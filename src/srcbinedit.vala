/* srcbinedit.vala
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
	[GtkTemplate (ui = "/standalone/glassroom/GlassRoom/srcbinedit.ui")]
	public class SrcBinEdit : Gtk.Box {

        private GlassRoom.SrcBin? _src_bin;
        private ulong src_bin_source_notify;
        private GLib.Binding? src_bin_bind_use_buffering;

        public GlassRoom.SrcBin? src_bin {
            get {
                return _src_bin;
            }
            set {
                if (_src_bin != null) {
                    _src_bin.disconnect (src_bin_source_notify);
                    src_bin_bind_use_buffering.unbind();
                    src_bin_bind_use_buffering = null;
                }
                _src_bin = null;

                if (value != null) {
                    entry_name.text = value.name;
                    entry_type.text = value.source_factory_name;
                    details.set_object_combo (value.source);
                    src_bin_source_notify = value.notify["source"].connect ((o, p) => {
                        details.set_object_combo (((GlassRoom.SrcBin)o).source);
                    });

                    src_bin_bind_use_buffering =
                    value.bind_property ("use-buffering", buffering_check_button, "active",
                    GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);
                }

                _src_bin = value;
            }
        }

        [GtkChild]
        private Gtk.Entry entry_name;

        [GtkChild]
        private Gtk.Entry entry_type;

        [GtkChild]
        private GlassRoom.PropertyForm details;

        [GtkChild]
        private Gtk.CheckButton buffering_check_button;

        [GtkCallback]
        private void on_name_changed (Gtk.Editable editable) {
            if (_src_bin != null) _src_bin.name = ((Gtk.Entry)editable).text;
        }

        [GtkCallback]
        private void on_type_changed (Gtk.Editable editable) {
            if (_src_bin != null) _src_bin.source_factory_name = ((Gtk.Entry)editable).text;
        }

	}
}
