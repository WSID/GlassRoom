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
        private Gst.Pad? composite_pad;

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

                    var value_pad = value.get_static_pad ("src").get_peer ();

                    if (value_pad != null) {
                        int xpos;
                        int ypos;
                        int width;
                        int height;
                        double alpha;

                        value_pad.get ( "xpos", out xpos,
                                        "ypos", out ypos,
                                        "width", out width,
                                        "height", out height,
                                        "alpha", out alpha);

                        xpos_spin.value = (double) xpos;
                        ypos_spin.value = (double) ypos;
                        width_spin.value = (double) width;
                        height_spin.value = (double) height;
                        alpha_spin.value = alpha;
                    }
                }

                _src_bin = value;
                composite_pad = _src_bin.get_static_pad ("src").get_peer();
            }
        }

        construct {
            GLib.SimpleActionGroup action_group = new GLib.SimpleActionGroup ();

            GLib.SimpleAction action_align = new GLib.SimpleAction ("align", new GLib.VariantType ("(ii)"));
            action_align.activate.connect (activate_align);

            action_group.add_action (action_align);

            align_popover.insert_action_group ("composite", action_group);
        }

        [GtkChild]
        private Gtk.Entry entry_name;

        [GtkChild]
        private Gtk.Entry entry_type;

        [GtkChild]
        private GlassRoom.PropertyForm details;

        [GtkChild]
        private Gtk.CheckButton buffering_check_button;

        [GtkChild]
        private Gtk.SpinButton xpos_spin;

        [GtkChild]
        private Gtk.SpinButton ypos_spin;

        [GtkChild]
        private Gtk.SpinButton width_spin;

        [GtkChild]
        private Gtk.SpinButton height_spin;

        [GtkChild]
        private Gtk.SpinButton alpha_spin;

        [GtkChild]
        private Gtk.Popover align_popover;

        [GtkCallback]
        private void on_name_changed (Gtk.Editable editable) {
            if (_src_bin != null) _src_bin.name = ((Gtk.Entry)editable).text;
        }

        [GtkCallback]
        private void on_type_changed (Gtk.Editable editable) {
            if (_src_bin != null) _src_bin.source_factory_name = ((Gtk.Entry)editable).text;
        }

        [GtkCallback]
        private void on_xpos_changed (Gtk.SpinButton spin) {
            if (composite_pad != null) composite_pad.set ("xpos", (int) spin.value);
        }

        [GtkCallback]
        private void on_ypos_changed (Gtk.SpinButton spin) {
            if (composite_pad != null) composite_pad.set ("ypos", (int) spin.value);
        }

        [GtkCallback]
        private void on_width_changed (Gtk.SpinButton spin) {
            if (composite_pad != null) composite_pad.set ("width", (int) spin.value);
        }

        [GtkCallback]
        private void on_height_changed (Gtk.SpinButton spin) {
            if (composite_pad != null) composite_pad.set ("height", (int) spin.value);
        }

        [GtkCallback]
        private void on_alpha_changed (Gtk.SpinButton spin) {
            if (composite_pad != null) composite_pad.set ("alpha", spin.value);
        }

        private void activate_align (Variant? variant) {
            GlassRoom.Application app = (GlassRoom.Application) GLib.Application.get_default();

            Gst.Caps src_caps = src_bin.get_static_pad ("src").get_current_caps();
            unowned Gst.Structure src_caps_struct = src_caps.get_structure (0);

            int video_width = app.video_width;
            int video_height = app.video_height;
            int src_width = 0;
            int src_height = 0;

            int xindex = 1;
            int yindex = 1;

            src_caps_struct.get_int ("width", out src_width);
            src_caps_struct.get_int ("height", out src_height);

            variant.get("(ii)", out xindex, out yindex);

            int nxpos;
            int nypos;
            int nwidth;
            int nheight;

            align_pos (video_width, src_width, xindex, out nxpos, out nwidth);
            align_pos (video_height, src_height, yindex, out nypos, out nheight);

            xpos_spin.value = (double) nxpos;
            ypos_spin.value = (double) nypos;
            width_spin.value = (double) nwidth;
            height_spin.value = (double) nheight;
        }

        private void align_pos (int screen_len, int item_len, int index, out int item_pos, out int item_nlen) {
            switch (index) {
            case 0:
                item_pos = 0;
                item_nlen = item_len;
                break;

            case 1:
                item_pos = (screen_len - item_len) / 2;
                item_nlen = item_len;
                break;

            case 2:
                item_pos = (screen_len - item_len);
                item_nlen = item_len;
                break;

            case 3:
                item_pos = 0;
                item_nlen = screen_len;
                break;
            }
        }
	}
}
