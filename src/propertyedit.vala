/* propertyedit.vala
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
     * Interface for property value editor.
     *
     * Both of parameter spec and value can be setted. Parameter spec sets how
     * values would be limited, and how values would be edited. Then, the value
     * can be setted and getted.
     */
    public interface PropertyEdit : Gtk.Widget {
        /**
         * This table maintains map of Type: Value type -> Editor type.
         */
        private static Once<HashTable<Type, Type>> once_table_value_edit;
        private static HashTable<Type, Type> prepare_table() {
            HashTable<Type, Type> table = new GLib.HashTable<Type, Type> (null, null);
            table[typeof (bool)] = typeof (PropertyEditBool);
            table[typeof (int)] = typeof (PropertyEditInt);
            table[typeof (uint)] = typeof (PropertyEditUint);
            table[typeof (float)] = typeof (PropertyEditFloat);
            table[typeof (double)] = typeof (PropertyEditDouble);
            return (owned) table;
        }

        public static PropertyEdit? get_for_type (Type value_type) {
            unowned HashTable<Type, Type> table_value_edit;
            table_value_edit = once_table_value_edit.once(prepare_table);

            Type edit_type = table_value_edit[value_type];
            if (edit_type == Type.INVALID) {
                return null;
            }
            else {
                return Object.new(edit_type) as PropertyEdit;
            }
        }

        public static PropertyEdit? get_for_pspec (GLib.ParamSpec param_spec) {
            unowned HashTable<Type, Type> table_value_edit;
            table_value_edit = once_table_value_edit.once(prepare_table);

            Type value_type = param_spec.value_type;
            Type edit_type = table_value_edit[value_type];
            if (edit_type == Type.INVALID) {
                return null;
            }
            else {
                return Object.new(edit_type,
                                  prop_spec:param_spec,
                                  prop_value:param_spec.get_default_value())
                       as PropertyEdit;
            }
        }


        public abstract GLib.ParamSpec? prop_spec {get; set;}
        public abstract GLib.Value prop_value {get; set;}

        public virtual string? make_tooltip_markup () {
            if (prop_spec == null) return null;
            else {
                unowned string value_type = prop_spec.value_type.name();
                string def_value = prop_spec.get_default_value().strdup_contents();
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>$value_type</b>\n<b>Default</b>: $def_value\n$blurb";
            }
        }
    }

    public class PropertyEditBool: Gtk.CheckButton, GlassRoom.PropertyEdit {
        public GLib.ParamSpec? prop_spec {get; set;}
        public GLib.Value prop_value {
            get { return active; }
            set { active = (bool) value; }
        }

        public override void toggled () {
            base.toggled();
            notify_property("prop-value");
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecBoolean? pspec_boolean = prop_spec as GLib.ParamSpecBoolean;

            if (pspec_boolean == null) return null;
            else {
                string def_value = pspec_boolean.default_value ? "Yes" : "No";
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Yes-or-No choice</b>\n<b>Default</b>: $def_value\n$blurb";
            }
        }
    }

    public class PropertyEditInt: Gtk.SpinButton, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public GLib.ParamSpec? prop_spec {
            get { return _prop_spec; }
            set {
                GLib.ParamSpecInt? prop_spec_int = value as GLib.ParamSpecInt;
                _prop_spec = prop_spec_int;
                if (prop_spec_int != null) {
                    set_range ((double)prop_spec_int.minimum,
                               (double)prop_spec_int.maximum);
                }
            }
        }

        public GLib.Value prop_value {
            get { return get_value_as_int (); }
            set { value = (double) value.get_int(); }
        }

        public override void value_changed () {
            base.value_changed();
            notify_property("prop-value");
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecInt? pspec_int = prop_spec as GLib.ParamSpecInt;

            if (pspec_int == null) return null;
            else {
                int def_value = pspec_int.default_value;
                int minimum = pspec_int.minimum;
                int maximum = pspec_int.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }

    public class PropertyEditUint: Gtk.SpinButton, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public GLib.ParamSpec? prop_spec {
            get { return _prop_spec; }
            set {
                GLib.ParamSpecUInt? prop_spec_uint = value as GLib.ParamSpecUInt;
                _prop_spec = prop_spec_uint;
                if (prop_spec_uint != null) {
                    set_range ((double)prop_spec_uint.minimum,
                               (double)prop_spec_uint.maximum);
                }
            }
        }

        public GLib.Value prop_value {
            get { return (uint) value; }
            set { value = (double) value.get_uint(); }
        }

        public override void value_changed () {
            base.value_changed();
            notify_property("prop-value");
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecUInt? pspec_uint = prop_spec as GLib.ParamSpecUInt;

            if (pspec_uint == null) return null;
            else {
                uint def_value = pspec_uint.default_value;
                uint minimum = pspec_uint.minimum;
                uint maximum = pspec_uint.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Unsigned integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }

    public class PropertyEditFloat: Gtk.SpinButton, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public GLib.ParamSpec? prop_spec {
            get { return _prop_spec; }
            set {
                GLib.ParamSpecFloat? prop_spec_float = value as GLib.ParamSpecFloat;
                _prop_spec = prop_spec_float;
                if (prop_spec_float != null) {
                    set_range ((double)prop_spec_float.minimum,
                               (double)prop_spec_float.maximum);
                }
            }
        }

        public GLib.Value prop_value {
            get { return (float) get_value(); }
            set { value = (double) value.get_float(); }
        }

        public override void value_changed () {
            base.value_changed();
            notify_property("prop-value");
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecFloat? pspec_float = prop_spec as GLib.ParamSpecFloat;

            if (pspec_float == null) return null;
            else {
                float def_value = pspec_float.default_value;
                float minimum = pspec_float.minimum;
                float maximum = pspec_float.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Float value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }

    public class PropertyEditDouble: Gtk.SpinButton, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public GLib.ParamSpec? prop_spec {
            get { return _prop_spec; }
            set {
                GLib.ParamSpecDouble? prop_spec_double = value as GLib.ParamSpecDouble;
                _prop_spec = prop_spec_double;
                if (prop_spec_double != null) {
                    set_range (prop_spec_double.minimum,
                               prop_spec_double.maximum);
                }
            }
        }

        public GLib.Value prop_value {
            get { return value; }
            set { value = value.get_double(); }
        }

        public override void value_changed () {
            base.value_changed();
            notify_property("prop-value");
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecDouble? pspec_double = prop_spec as GLib.ParamSpecDouble;

            if (pspec_double == null) return null;
            else {
                double def_value = pspec_double.default_value;
                double minimum = pspec_double.minimum;
                double maximum = pspec_double.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Double precision float value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }
}
