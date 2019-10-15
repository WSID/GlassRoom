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
     * Type for property value editor.
     *
     * Both of parameter spec and value can be setted. Parameter spec sets how
     * values would be limited, and how values would be edited. Then, the value
     * can be setted and getted.
     *
     * ## Supported types.
     *
     * This is mainly targets to Gst.Element s. They tends to have properties of
     * primitive types, rather than composite types. So this just covers...
     *
     *  * Primitive type (boolean, int...)
     *  * Classed integer type. Currently enumeration types are supported.
     *  * Special boxed type like Gst.Fraction.
     */
    public abstract class PropertyEdit : GLib.Object {
        /**
         * This table maintains map of Type: Property type -> Editor type.
         */
        private static Once<HashTable<Type, Type>> once_table_prop_edit;
        private static HashTable<Type, Type> prepare_table() {
            HashTable<Type, Type> table = new GLib.HashTable<Type, Type> (null, null);
            table[typeof (ParamSpecBoolean)] = typeof (PropertyEditBool);
            table[typeof (ParamSpecInt)] = typeof (PropertyEditInt);
            table[typeof (ParamSpecUInt)] = typeof (PropertyEditUint);
            table[typeof (ParamSpecInt64)] = typeof (PropertyEditI64);
            table[typeof (ParamSpecUInt64)] = typeof (PropertyEditU64);
            table[typeof (ParamSpecFloat)] = typeof (PropertyEditFloat);
            table[typeof (ParamSpecDouble)] = typeof (PropertyEditDouble);
            table[typeof (ParamSpecString)] = typeof (PropertyEditString);
            table[typeof (ParamSpecEnum)] = typeof (PropertyEditEnum);
            table[typeof (Gst.ParamSpecFraction)] = typeof (PropertyEditFraction);
            return (owned) table;
        }

        public static PropertyEdit? get_for_pspec (GLib.ParamSpec param_spec) {
            unowned HashTable<Type, Type> table_prop_edit;
            table_prop_edit = once_table_prop_edit.once(prepare_table);

            Type prop_type = Type.from_instance (param_spec);
            Type edit_type = table_prop_edit[prop_type];
            if (edit_type == Type.INVALID) {
                return null;
            }
            else {
                return (PropertyEdit) Object.new(edit_type,
                                  property:param_spec,
                                  value:param_spec.get_default_value());
            }
        }

        /**
         * Type of accepted param spec.
         */
        public class Type prop_spec_type = typeof (GLib.ParamSpec);

        private GLib.ParamSpec _property;
        private GLib.Object? _object;

        private GLib.Binding? binding;

        // Primary properties.
        public GLib.ParamSpec property {
            get { return _property; }
            construct {
                Type in_type = Type.from_instance (value);
                if (! in_type.is_a (prop_spec_type))
                    warning ("ParamSpec type mismatch...\n" +
                             "    Required: %s, Actual: %s",
                             prop_spec_type.name(),
                             in_type.name());
                _property = value;
            }
        }
        public GLib.Object? object {
            get { return _object; }
            set {
                if (value == _object) return;

                if (binding != null) {
                    binding.unbind();
                    binding = null;
                }

                _object = value;

                bool suitable = object_is_suitable (_object);

                if (suitable) binding = bind_object (_object);
                widget.sensitive = suitable;
            }
        }
        public abstract Gtk.Widget widget { get; }
        public abstract GLib.Value value {owned get; set;}

        // Derived property for convenience;
        public string prop_name { get { return property.get_name(); } }
        public string prop_nick { get { return property.get_nick(); } }
        public string prop_blurb{ get { return property.get_blurb();} }

        public Type prop_type { get {return property.value_type;} }
        public Type prop_owner_type { get {return property.owner_type;} }

        public virtual string? make_tooltip_markup () {
            unowned string value_type = prop_type.name();
            string def_value = property.get_default_value().strdup_contents();
            unowned string blurb = prop_blurb;

            return @"<b>$value_type</b>\n<b>Default</b>: $def_value\n$blurb";
        }

        protected bool binding_prop_to_edit (Binding binding, Value from, ref Value to) {
            to.set_boxed (&from);
            return true;
        }

        protected bool binding_edit_to_prop (Binding binding, Value from, ref Value to) {
            unowned Value? from_actual = (Value?) from.get_boxed();
            from_actual.copy (ref to);
            return true;
        }

        protected Binding bind_object (GLib.Object object) {
            return object.bind_property (prop_name, this, "value",
                BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE,
                binding_prop_to_edit,
                binding_edit_to_prop);
        }

        protected bool object_is_suitable (Object object) {
            return object.get_type().is_a (prop_owner_type);
        }
    }

    public class PropertyEditBool: PropertyEdit {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecBoolean);
        }

        private Gtk.CheckButton check_button;

        public override GLib.Value value {
            owned get { return check_button.active; }
            set { check_button.active = (bool) value; }
        }
        public override Gtk.Widget widget { get { return check_button; } }

        construct {
            check_button = new Gtk.CheckButton ();
            check_button.toggled.connect (() => notify_property ("value"));
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecBoolean pspec_boolean = (GLib.ParamSpecBoolean) property;
            string def_value = pspec_boolean.default_value ? "Yes" : "No";
            unowned string blurb = prop_blurb;

            return @"<b>Yes-or-No choice</b>\n<b>Default</b>: $def_value\n$blurb";
        }
    }

    public abstract class PropertyEditNum: PropertyEdit {
        protected Gtk.SpinButton spin_button;

        public override Gtk.Widget widget { get { return spin_button; } }

        construct {
            spin_button = new Gtk.SpinButton (make_adjustment(), 1.0, 4);
            spin_button.changed.connect (() => notify_property ("value"));
        }

        public abstract Gtk.Adjustment make_adjustment ();
    }

    public class PropertyEditInt: GlassRoom.PropertyEditNum {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecInt);
        }

        public override GLib.Value value {
            owned get { return spin_button.get_value_as_int (); }
            set { spin_button.value = (double) value.get_int(); }
        }

        construct {
            spin_button.digits = 0;
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecInt pspec_int = (GLib.ParamSpecInt) property;

            int def_value = pspec_int.default_value;
            int minimum = pspec_int.minimum;
            int maximum = pspec_int.maximum;
            unowned string blurb = prop_blurb;

            return @"<b>Integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
        }

        public override Gtk.Adjustment make_adjustment () {
            GLib.ParamSpecInt pspec_int = (GLib.ParamSpecInt) property;

            return new Gtk.Adjustment ((double) pspec_int.default_value,
                                       (double) pspec_int.minimum,
                                       (double) pspec_int.maximum,
                                       1.0, 10.0, 50.0);
        }
    }

    public class PropertyEditUint: GlassRoom.PropertyEditNum {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecUInt);
        }

        public override GLib.Value value {
            owned get { return (uint) spin_button.value; }
            set { spin_button.value = (double) value.get_uint(); }
        }

        construct {
            spin_button.digits = 0;
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecUInt pspec_uint = (GLib.ParamSpecUInt) property;

            uint def_value = pspec_uint.default_value;
            uint minimum = pspec_uint.minimum;
            uint maximum = pspec_uint.maximum;
            unowned string blurb = prop_blurb;

            return @"<b>Unsigned integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
        }

        public override Gtk.Adjustment make_adjustment () {
            GLib.ParamSpecUInt pspec_uint = (GLib.ParamSpecUInt) property;

            return new Gtk.Adjustment ((double) pspec_uint.default_value,
                                       (double) pspec_uint.minimum,
                                       (double) pspec_uint.maximum,
                                       1.0, 10.0, 50.0);
        }
    }

    public class PropertyEditFloat: GlassRoom.PropertyEditNum {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecFloat);
        }
        public override GLib.Value value {
            owned get { return (float) spin_button.value; }
            set { spin_button.value = (double) value.get_float(); }
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecFloat pspec_float = (GLib.ParamSpecFloat) property;

            if (pspec_float == null) return null;
            else {
                float def_value = pspec_float.default_value;
                float minimum = pspec_float.minimum;
                float maximum = pspec_float.maximum;
                unowned string blurb = prop_blurb;

                return @"<b>Float value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
            }
        }

        public override Gtk.Adjustment make_adjustment () {
            GLib.ParamSpecFloat pspec_float = (GLib.ParamSpecFloat) property;

            return new Gtk.Adjustment ((double) pspec_float.default_value,
                                       (double) pspec_float.minimum,
                                       (double) pspec_float.maximum,
                                       1.0, 10.0, 50.0);
        }
    }

    public class PropertyEditDouble: PropertyEditNum {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecDouble);
        }

        public override GLib.Value value {
            owned get { return spin_button.value; }
            set { spin_button.value = value.get_double(); }
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecDouble pspec_double = (GLib.ParamSpecDouble) property;
            double def_value = pspec_double.default_value;
            double minimum = pspec_double.minimum;
            double maximum = pspec_double.maximum;
            unowned string blurb = prop_blurb;

            return @"<b>Double precision float value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
        }

        public override Gtk.Adjustment make_adjustment () {
            GLib.ParamSpecDouble pspec_double = (GLib.ParamSpecDouble) property;

            return new Gtk.Adjustment ((double) pspec_double.default_value,
                                       (double) pspec_double.minimum,
                                       (double) pspec_double.maximum,
                                       1.0, 10.0, 50.0);
        }
    }

    // I cannot use Gtk.SpinButton. The spin button uses double, and the
    // precision was 31bit, not 64bit.
    public class PropertyEditI64: PropertyEdit {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecInt64);
        }

        private Gtk.Entry entry;
        private int64 value_int;

        public override GLib.Value value {
            owned get {
                return value_int;
            }
            set {
                value_int = value.get_int64();
                entry.text = value_int.to_string();
            }
        }
        public override Gtk.Widget widget { get { return entry; } }

        construct {
            entry = new Gtk.Entry ();
            entry.input_purpose = Gtk.InputPurpose.NUMBER;
            entry.changed.connect (() => {
                unowned string text = entry.text;
                unowned string unparsed;
                int64 nvalue;
                if (! int64.try_parse (text, out nvalue, out unparsed)) {
                    GLib.Signal.stop_emission_by_name (entry, "changed");
                    entry.text = text[0 : text.pointer_to_offset(unparsed)];
                }

                GLib.ParamSpecInt64? pspec_i64 = (GLib.ParamSpecInt64) property;
                nvalue = nvalue.clamp(pspec_i64.minimum, pspec_i64.maximum);

                if (nvalue != value_int) {
                    value_int = nvalue;
                    notify_property ("value");
                }
            });
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecInt64? pspec_i64 = (GLib.ParamSpecInt64) property;

            int64 def_value = pspec_i64.default_value;
            int64 minimum = pspec_i64.minimum;
            int64 maximum = pspec_i64.maximum;
            unowned string blurb = prop_blurb;

            return @"<b>64-bit integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
        }

    }

    public class PropertyEditU64: PropertyEdit {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecUInt64);
        }

        private Gtk.Entry entry;
        private uint64 value_uint;

        public override GLib.Value value {
            owned get {
                return value_uint;
            }
            set {
                value_uint = value.get_uint64();
                entry.text = value_uint.to_string();
            }
        }
        public override Gtk.Widget widget { get { return entry; } }

        construct {
            entry = new Gtk.Entry ();
            entry.input_purpose = Gtk.InputPurpose.NUMBER;

            entry.changed.connect (() => {
                unowned string text = entry.text;
                unowned string unparsed;
                uint64 nvalue;
                if (! int64.try_parse (text, out nvalue, out unparsed)) {
                    GLib.Signal.stop_emission_by_name (entry, "changed");
                    entry.text = text[0 : text.pointer_to_offset(unparsed)];
                }

                GLib.ParamSpecUInt64? pspec_u64 = (GLib.ParamSpecUInt64) property;
                nvalue = nvalue.clamp(pspec_u64.minimum, pspec_u64.maximum);

                if (nvalue != value_uint) {
                    value_uint = nvalue;
                    notify_property ("value");
                }
            });
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecUInt64? pspec_u64 = (GLib.ParamSpecUInt64) property;

            uint64 def_value = pspec_u64.default_value;
            uint64 minimum = pspec_u64.minimum;
            uint64 maximum = pspec_u64.maximum;
            unowned string blurb = prop_blurb;

            return @"<b>64-bit integer value</b>\n<b>Default</b>: $def_value\n<b>Minimum</b>: $minimum\n<b>Maximum</b>: $maximum\n$blurb";
        }
    }

    public class PropertyEditString: PropertyEdit {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecString);
        }

        private Gtk.Entry entry;

        public override GLib.Value value {
            owned get { return entry.text; }
            set { entry.text = value.get_string() ?? ""; }
        }
        public override Gtk.Widget widget { get { return entry; } }

        construct {
            entry = new Gtk.Entry ();
            entry.changed.connect (() => notify_property ("value"));
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecString pspec_string = (GLib.ParamSpecString) property;
            if (pspec_string == null) return null;
            else {
                unowned string def_value = pspec_string.default_value ?? "";
                unowned string blurb = prop_blurb;

                return @"<b>Text</b>\n<b>Default</b>: $def_value\n$blurb";
            }
        }
    }


    public class PropertyEditEnum: PropertyEdit {
        class construct {
            prop_spec_type = typeof (GLib.ParamSpecEnum);
        }

        private Gtk.ComboBox combo;
        private Gtk.ListStore? list_store; // (Enum Type) string.
        // list_store holds int for value, string for presentation.

        private GLib.EnumClass enum_cls {
            get { return ((GLib.ParamSpecEnum)property).enum_class; }
        }

        public override GLib.Value value {
            owned get {
                Gtk.TreeIter enum_iter;
                GLib.Value enum_value;

                combo.get_active_iter (out enum_iter);
                list_store.get_value(enum_iter, 0, out enum_value);
                return enum_value;
            }
            set {
                int int_value = value.get_enum ();

                for (int index = 0; index < enum_cls.n_values; index++) {
                    if (enum_cls.values[index].value == int_value) {
                        combo.active = index;
                        break;
                    }
                }
            }
        }

        public override Gtk.Widget widget { get { return combo; } }

        construct {
            list_store = new Gtk.ListStore (3, prop_type, typeof (string), typeof (string));

            foreach (unowned EnumValue enum_value in enum_cls.values) {
                Gtk.TreeIter iter;
                list_store.append (out iter);
                list_store.set (iter,
                                0, enum_value.value,
                                1, enum_value.value_name,
                                2, enum_value.value_nick);
            }

            Gtk.CellAreaBox cell_area = new Gtk.CellAreaBox ();
            Gtk.CellRendererText cell_text = new Gtk.CellRendererText ();
            cell_text.visible = true;

            cell_area.pack_start (cell_text, true);
            cell_area.add_attribute (cell_text, "text", 2);

            combo = new Gtk.ComboBox.with_area (cell_area);
            combo.model = list_store;
            combo.id_column = 1;
            combo.changed.connect (() => notify_property("value"));
        }

        public override string? make_tooltip_markup () {
            GLib.ParamSpecEnum pspec_enum = (GLib.ParamSpecEnum) property;
            unowned EnumValue? def_value_enum = enum_cls.get_value(pspec_enum.default_value);

            unowned string type_name = pspec_enum.value_type.name();
            unowned string def_value = def_value_enum.value_nick;
            unowned string blurb = prop_blurb;

            return @"<b>Choice ($type_name)</b>\n<b>Default</b>: $def_value\n$blurb";
        }

    }


    // With existence of '/', the edit will be applied when focus is lost, or
    // activated (user pressed Enter on Entry, ...)
    public class PropertyEditFraction: PropertyEdit {
        private int num = 1;
        private int den = 1;

        private bool editing;

        private Gtk.Entry entry;

        [CCode (cname="gst_value_set_fraction")]
        private static extern void value_set_fraction(ref Value value, int num, int den);

        public override Value value {
            owned get {
                Value value = Value (typeof (Gst.Fraction));
                value_set_fraction (ref value, num, den);
                return value;
            }
            set {
                num = Gst.Value.get_fraction_numerator (value);
                den = Gst.Value.get_fraction_denominator (value);

                entry.text = @"$num / $den";
                editing = false;
            }
        }
        public override Gtk.Widget widget { get { return entry; } }

        construct {
            entry = new Gtk.Entry ();
            entry.activate.connect (() => commit_edit());
            entry.focus_out_event.connect (() => {
                commit_edit();
                return false;
            });

            entry.changed.connect (() => { editing = true; });
        }

        public override string? make_tooltip_markup () {
            Gst.ParamSpecFraction* pspec_frac = (Gst.ParamSpecFraction*) (property);

            int def_num = pspec_frac->def_num;
            int def_den = pspec_frac->def_den;
            int min_num = pspec_frac->min_num;
            int min_den = pspec_frac->min_den;
            int max_num = pspec_frac->max_num;
            int max_den = pspec_frac->max_den;

            unowned string blurb = prop_blurb;

            return @"<b>Fractional value</b>\n<b>Default</b>: $def_num / $def_den\n<b>Minimum</b>: $min_num / $min_den\n<b>Maximum</b>: $max_num / $max_den\n$blurb";
        }

        private void commit_edit () {
            int items = entry.text.scanf ("%d / %d", out num, out den);

            if (items == 1) den = 1;

            entry.text = @"$num / $den";
            notify_property("value");
            editing = false;
        }
    }
}
