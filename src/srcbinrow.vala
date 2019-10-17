/* srcbinrow.vala
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
	[GtkTemplate (ui = "/standalone/glassroom/GlassRoom/srcbinrow.ui")]
	public class SrcBinRow : Gtk.ListBoxRow {

        public GlassRoom.SrcBin src_bin {get; construct;}

        [GtkChild]
        private Gtk.Label label_name;

        [GtkChild]
        private Gtk.Label label_type;

        [GtkChild]
        private Gtk.Switch switch_active;

	    construct {
            src_bin.bind_property ("name", label_name, "label", BindingFlags.SYNC_CREATE);
            src_bin.bind_property ("source_factory_name", label_type, "label", BindingFlags.SYNC_CREATE);
            switch_active.state_set.connect ((state) => {
                src_bin.set_state (state ? Gst.State.PLAYING : Gst.State.NULL);
                return state;
            });

            GLib.SimpleActionGroup action_group = new GLib.SimpleActionGroup();

            GLib.SimpleAction action_edit = new GLib.SimpleAction ("edit", null);
            action_edit.activate.connect (activate_edit);

            GLib.SimpleAction action_delete = new GLib.SimpleAction ("delete", null);
            action_delete.activate.connect (activate_delete);

            action_group.add_action (action_edit);
            action_group.add_action (action_delete);

            insert_action_group ("row", action_group);
	    }

        public SrcBinRow (GlassRoom.SrcBin src_bin) {
            Object (src_bin: src_bin);
        }

        private void activate_edit (Variant? param) {
            GlassRoom.Window? aw = get_toplevel() as GlassRoom.Window;

            if (aw != null) aw.edit_sources (src_bin);
        }

        private void activate_delete (Variant? param) {
            GlassRoom.Application? ap = GLib.Application.get_default() as GlassRoom.Application;

            if (ap != null) ap.remove_source (src_bin);
        }
	}
}
