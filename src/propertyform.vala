/* propertyform.vala
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
    public class PropertyForm: Gtk.Grid {
        private Type _object_type;
        private Object? _object;

        public Type object_type {
            get {
                return _object_type;
            }
            set {
                if ((value != Type.INVALID) && (! value.is_object())) {
                    value = Type.INVALID;
                    warning ("The type is required to be object: %s", value.name());
                }

                if (value == _object_type) return;

                _object_type = value;
                forall ((w) => remove(w));

                if (value != Type.INVALID) {
                    GLib.ObjectClass? object_cls = (GLib.ObjectClass) value.class_ref();
                    if (object_cls == null) return;
                    (unowned ParamSpec)[] param_specs = object_cls.list_properties ();

                    int row = 0;
                    foreach (unowned ParamSpec param_spec in param_specs) {
                        if (attach_edit_row (param_spec, row)) row++;
                    }
                }
            }
        }

        public Object? object {
            get {
                return _object;
            }
            set {
                _object = value;
            }
        }

        /**
         * Sets both of object_type and object at once.
         */
        public void set_object_combo (Object? object) {
            object_type = (object != null) ? object.get_type() : Type.INVALID;
            this.object = object;
        }

        private bool attach_edit_row (ParamSpec pspec, int row) {
            // [Label] [Editor] [Reset Button]
            GlassRoom.PropertyEdit? editor = GlassRoom.PropertyEdit.get_for_pspec(pspec);

            if (editor != null) {
                Gtk.Label label = new Gtk.Label (pspec.get_nick());
                Gtk.Button reset_button = new Gtk.Button.from_icon_name("edit-clear-all-symbolic");

                Value default_value = pspec.get_default_value();

                string tooltip_pspec = editor.make_tooltip_markup ();
                string tooltip_reset = @"<b>Default</b>\n$(default_value.strdup_contents())";

                label.tooltip_markup = tooltip_pspec;
                editor.tooltip_markup = tooltip_pspec;
                reset_button.tooltip_markup = tooltip_reset;

                label.visible = true;
                editor.visible = true;
                reset_button.visible = true;

                label.xalign = 0.0f;
                editor.hexpand = true;

                editor.prop_value = default_value;

                // Attach UI
                attach (label, 0, row);
                attach (editor, 1, row);
                attach (reset_button, 2, row);

                //TODO: connect signals, and bind editor:value <-> object's own property.
                //ulong editor_notify_handle;
                //ulong object_notify_hanlde;
                //editor_notify_handle = editor.notify["value"].connect (() => {
                //    GLib.SignalHandler.block ()
                //});
            }

            return (editor != null);
        }
    }
}
