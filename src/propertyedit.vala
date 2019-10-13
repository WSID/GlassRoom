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
            table[typeof (int64)] = typeof (PropertyEditI64);
            table[typeof (uint64)] = typeof (PropertyEditU64);
            table[typeof (float)] = typeof (PropertyEditFloat);
            table[typeof (double)] = typeof (PropertyEditDouble);
            table[typeof (string)] = typeof (PropertyEditString);
            table[typeof (Gst.Fraction)] = typeof (PropertyEditFraction);
            return (owned) table;
        }

        public static Type get_editor_type_for (Type value_type) {
            unowned HashTable<Type, Type> table_value_edit;
            table_value_edit = once_table_value_edit.once(prepare_table);

            Type editor_type = table_value_edit[value_type];
            if (editor_type != Type.INVALID) return editor_type;

            if (value_type.is_enum()) return typeof (PropertyEditEnum);
            return Type.INVALID;
        }

        public static PropertyEdit? get_for_type (Type value_type) {
            Type edit_type = get_editor_type_for (value_type);
            if (edit_type == Type.INVALID) {
                return null;
            }
            else {
                return Object.new(edit_type) as PropertyEdit;
            }
        }

        public static PropertyEdit? get_for_pspec (GLib.ParamSpec param_spec) {
            Type edit_type = get_editor_type_for (param_spec.value_type);
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
        public abstract GLib.Value prop_value {owned get; set;}

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
            owned get { return active; }
            set { active = (bool) value; }
        }

        construct {
            toggled.connect (() => notify_property("prop-value"));
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

    public abstract class PropertyEditNum: Gtk.SpinButton, GlassRoom.PropertyEdit {
        public abstract GLib.ParamSpec? prop_spec {get; set;}
        public abstract GLib.Value prop_value {owned get; set;}

        construct {
            value_changed.connect (() => notify_property("prop-value"));
        }
    }

    public class PropertyEditInt: GlassRoom.PropertyEditNum, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public override GLib.ParamSpec? prop_spec {
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

        public override GLib.Value prop_value {
            owned get { return get_value_as_int (); }
            set { this.value = (double) value.get_int(); }
        }

        public string? make_tooltip_markup () {
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

    public class PropertyEditUint: GlassRoom.PropertyEditNum, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public override GLib.ParamSpec? prop_spec {
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

        public override GLib.Value prop_value {
            owned get { return (uint) value; }
            set { this.value = (double) value.get_uint(); }
        }

        public string? make_tooltip_markup () {
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

    public class PropertyEditFloat: GlassRoom.PropertyEditNum, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public override GLib.ParamSpec? prop_spec {
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

        public override GLib.Value prop_value {
            owned get { return (float) get_value(); }
            set { this.value = (double) value.get_float(); }
        }

        public string? make_tooltip_markup () {
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

    public class PropertyEditDouble: GlassRoom.PropertyEditNum, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;

        public override GLib.ParamSpec? prop_spec {
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

        public override GLib.Value prop_value {
            owned get { return value; }
            set { this.value = value.get_double(); }
        }

        public string? make_tooltip_markup () {
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

    // I cannot use Gtk.SpinButton. The spin button uses double, and the
    // precision was 31bit, not 64bit.
    public class PropertyEditI64: Gtk.Entry, GlassRoom.PropertyEdit {
        private int64 prop_value_int;

        public GLib.ParamSpec? prop_spec {get; set;}
        public GLib.Value prop_value {
            owned get {
                return prop_value_int;
            }
            set {
                prop_value_int = value.get_int64();
                text = prop_value_int.to_string();
            }
        }

        construct {
            input_purpose = Gtk.InputPurpose.NUMBER;

            changed.connect (() => {
                unowned string unparsed;
                int64 nvalue;
                if (! int64.try_parse (text, out nvalue, out unparsed)) {
                    GLib.Signal.stop_emission_by_name (this, "changed");
                    text = text[0 : text.pointer_to_offset(unparsed)];
                }

                GLib.ParamSpecInt64? pspec_i64 = prop_spec as GLib.ParamSpecInt64;

                if (pspec_i64 != null) {
                    nvalue = nvalue.clamp(pspec_i64.minimum, pspec_i64.maximum);
                }

                if (nvalue != prop_value_int) {
                    prop_value_int = nvalue;
                    notify_property ("prop-value");
                }
            });
        }

        public string? make_tooltip_markup () {
            GLib.ParamSpecInt64? pspec_i64 = prop_spec as GLib.ParamSpecInt64;

            if (pspec_i64 == null) return null;
            else {
                int64 def_value = pspec_i64.default_value;
                int64 minimum = pspec_i64.minimum;
                int64 maximum = pspec_i64.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>64-bit integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }

    public class PropertyEditU64: Gtk.Entry, GlassRoom.PropertyEdit {
        private uint64 prop_value_uint;

        public GLib.ParamSpec? prop_spec {get; set;}
        public GLib.Value prop_value {
            owned get {
                return prop_value_uint;
            }
            set {
                prop_value_uint = value.get_uint64();
                text = prop_value_uint.to_string();
            }
        }

        construct {
            input_purpose = Gtk.InputPurpose.NUMBER;

            changed.connect (() => {
                unowned string unparsed;
                uint64 nvalue;
                if (! int64.try_parse (text, out nvalue, out unparsed)) {
                    GLib.Signal.stop_emission_by_name (this, "changed");
                    text = text[0 : text.pointer_to_offset(unparsed)];
                }

                GLib.ParamSpecUInt64? pspec_u64 = prop_spec as GLib.ParamSpecUInt64;

                if (pspec_u64 != null) {
                    nvalue = nvalue.clamp(pspec_u64.minimum, pspec_u64.maximum);
                }

                if (nvalue != prop_value_uint) {
                    prop_value_uint = nvalue;
                    notify_property ("prop-value");
                }
            });
        }

        public string? make_tooltip_markup () {
            GLib.ParamSpecUInt64? pspec_u64 = prop_spec as GLib.ParamSpecUInt64;

            if (pspec_u64 == null) return null;
            else {
                uint64 def_value = pspec_u64.default_value;
                uint64 minimum = pspec_u64.minimum;
                uint64 maximum = pspec_u64.maximum;
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>64-bit integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }
    }

    public class PropertyEditString: Gtk.Entry, GlassRoom.PropertyEdit {
        public GLib.ParamSpec? prop_spec {get; set; }

        public GLib.Value prop_value {
            owned get { return text; }
            set { text = value.get_string() ?? ""; }
        }

        construct {
            changed.connect (() => notify_property("prop-value"));
        }

        public virtual string? make_tooltip_markup () {
            GLib.ParamSpecString? pspec_string = prop_spec as GLib.ParamSpecString;
            if (pspec_string == null) return null;
            else {
                unowned string def_value = pspec_string.default_value ?? "";
                unowned string blurb = prop_spec.get_blurb();

                return @"<b>Text</b>\n<b>Default</b>: $def_value\n$blurb";
            }
        }
    }

    public class PropertyEditEnum: Gtk.ComboBox, GlassRoom.PropertyEdit {
        private GLib.ParamSpec? _prop_spec;
        private GLib.EnumClass? enum_cls;
        private Gtk.ListStore? list_store; // (Enum Type), string.

        // list_store holds int for value, string for presentation.

        public GLib.ParamSpec? prop_spec {
            get {
                return _prop_spec;
            }
            set {
                GLib.ParamSpecEnum? pspec_enum = value as GLib.ParamSpecEnum;
                if (_prop_spec == pspec_enum) return;

                _prop_spec = pspec_enum;

                if (_prop_spec != null) {
                    Type enum_type = _prop_spec.value_type;
                    enum_cls = (GLib.EnumClass) enum_type.class_ref();
                    list_store = new Gtk.ListStore (3, enum_type, typeof (string), typeof (string));

                    foreach (unowned EnumValue enum_value in enum_cls.values) {
                        Gtk.TreeIter iter;
                        list_store.append (out iter);
                        list_store.set (iter,
                                        0, enum_value.value,
                                        1, enum_value.value_name,
                                        2, enum_value.value_nick);
                    }

                    set_model(list_store);
                }
                else {
                    enum_cls = null;
                    list_store = null;
                    set_model(null);
                }
            }
        }

        public GLib.Value prop_value {
            owned get {
                if (enum_cls != null) {
                    Gtk.TreeIter enum_iter;
                    GLib.Value enum_value;

                    get_active_iter (out enum_iter);
                    list_store.get_value(enum_iter, 0, out enum_value);
                    return enum_value;
                }
                else {
                    return (int)0;
                }
            }
            set {
                if (enum_cls != null) {
                    int int_value = value.get_enum ();

                    for (int index = 0; index < enum_cls.n_values; index++) {
                        if (enum_cls.values[index].value == int_value) {
                            active = index;
                            break;
                        }
                    }
                }
            }
        }

        construct {
            Gtk.CellAreaBox cell_area = new Gtk.CellAreaBox ();
            Gtk.CellRendererText cell_text = new Gtk.CellRendererText ();
            cell_text.visible = true;

            cell_area.pack_start (cell_text, true);
            cell_area.add_attribute (cell_text, "text", 2);
            this.cell_area = cell_area;

            id_column = 1;

            changed.connect (() => notify_property("prop-value"));
        }

        public virtual string? make_tooltip_markup () {
            GLib.ParamSpecEnum? pspec_enum = prop_spec as GLib.ParamSpecEnum;
            if (pspec_enum == null) return null;
            else {
                unowned EnumValue? def_value_enum = enum_cls.get_value(pspec_enum.default_value);

                unowned string type_name = pspec_enum.value_type.name();
                unowned string def_value = def_value_enum.value_nick;
                unowned string blurb = pspec_enum.get_blurb();

                return @"<b>Choice ($type_name)</b>\n<b>Default</b>: $def_value\n$blurb";
            }
        }
    }

    // With existence of '/', the edit will be applied when focus is lost, or
    // activated (user pressed Enter on Entry, ...)
    public class PropertyEditFraction: Gtk.Entry, GlassRoom.PropertyEdit {
        private int num = 1;
        private int den = 1;

        private bool editing;

        [CCode (cname="gst_value_set_fraction")]
        private static extern void value_set_fraction(ref Value value, int num, int den);

        public ParamSpec? prop_spec {get; set; }

        public Value prop_value {
            owned get {
                Value value = Value (typeof (Gst.Fraction));
                value_set_fraction (ref value, num, den);
                return value;
            }
            set {
                num = Gst.Value.get_fraction_numerator (value);
                den = Gst.Value.get_fraction_denominator (value);

                text = @"$num / $den";
                editing = false;
            }
        }

        construct {
            activate.connect (() => commit_edit());
            focus_out_event.connect (() => {
                commit_edit();
                return false;
            });

            changed.connect (() => {
                editing = true;
            });
        }

        public virtual string? make_tooltip_markup () {
            if (prop_spec == null) return null;
            if (prop_spec.value_type != typeof (Gst.Fraction)) return null;

            Gst.ParamSpecFraction* pspec_frac = (Gst.ParamSpecFraction*) (prop_spec);

            int def_num = pspec_frac->def_num;
            int def_den = pspec_frac->def_den;
            int min_num = pspec_frac->min_num;
            int min_den = pspec_frac->min_den;
            int max_num = pspec_frac->max_num;
            int max_den = pspec_frac->max_den;

            unowned string blurb = prop_spec.get_blurb();

            return @"<b>Fractional value</b>\n<b>Default</b>: $def_num / $def_den\n<b>Minimum</b>: $min_num / $min_den\n<b>Maximum</b>: $max_num / $max_den\n$blurb";
        }

        private void commit_edit () {
            int items = text.scanf ("%d / %d", out num, out den);

            if (items == 1) den = 1;

            text = @"$num / $den";
            editing = false;
        }
    }
}
