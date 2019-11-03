/* recordoptionview.vala
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
	[GtkTemplate (ui = "/standalone/glassroom/GlassRoom/recordoptionview.ui")]
    public class RecordOptionView: Gtk.Stack {


        [GtkChild(name="base-path-button")]
        private Gtk.FileChooserButton base_path_button;

        [GtkChild(name="file-name-entry")]
        private Gtk.Entry file_name_entry;

        [GtkChild]
        private Gtk.SpinButton video_width_spin;

        [GtkChild]
        private Gtk.SpinButton video_height_spin;

        [GtkChild]
        private Gtk.Entry video_framerate_entry;

        private int video_framerate_num;
        private int video_framerate_den;

        // TODO: Interact with GSettings, rather than application.
        public GlassRoom.Application application { get; set; }

        construct {
            // base_path_button defaults.
            string default_base_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS);
            base_path_button.select_file (GLib.File.new_for_path (default_base_path));
        }

        public void apply_profile () {
            application.encoding_profile = make_container_profile ();
            application.set_video_format (make_video_format());
        }

        private Gst.PbUtils.EncodingContainerProfile make_container_profile () {
            Gst.PbUtils.EncodingContainerProfile profile =
            new Gst.PbUtils.EncodingContainerProfile (
                "Ogg audio/video",
                "Standard OGG/THEORA/VORBIS",
                Gst.Caps.from_string ("application/ogg"), null);

            profile.add_profile (make_video_profile ());

            return profile;
        }

        private Gst.PbUtils.EncodingVideoProfile make_video_profile () {
            return new Gst.PbUtils.EncodingVideoProfile (make_video_format("video/x-theora"), null, null, 0);
        }

        private Gst.Caps make_video_format (string media_format = "video/x-raw") {
            return new Gst.Caps.simple (media_format,
                "width", typeof (int), video_width_spin.get_value_as_int(),
                "height", typeof (int),  video_height_spin.get_value_as_int(),
                "framerate", typeof (Gst.Fraction),
                    video_framerate_num,
                    video_framerate_den);    // TODO: Apply framerate from entry.
        }

        [GtkCallback]
        private void on_path_to_file () {
            GLib.File base_path = base_path_button.get_file ();
            string file_name = file_name_entry.text;

            GLib.File? base_path_parent = base_path.get_parent();

            if (base_path_parent != null) {
                file_name_entry.text = base_path.get_basename() + "/" + file_name;
                base_path_button.select_file (base_path_parent);
            }
        }

        [GtkCallback]
        private void on_file_to_path () {
            GLib.File base_path = base_path_button.get_file ();
            string file_name = file_name_entry.text;

            int sep_index = file_name.index_of_char ('/');
            if (sep_index == -1) return;

            string file_seg = file_name[0:sep_index];

            base_path = base_path.get_child (file_seg);
            if ((! base_path.query_exists ()) || (base_path.query_file_type(0) != GLib.FileType.DIRECTORY)) return;

            base_path_button.select_file (base_path);
            file_name_entry.text = file_name.substring (sep_index + 1);
        }

        [GtkCallback]
        private void on_base_path_set (Gtk.FileChooser file_chooser) {
            application.file_base_path = file_chooser.get_file ();
        }

        [GtkCallback]
        private void on_file_name_set (Gtk.Editable editable) {
            application.file_name = file_name_entry.text;
        }

        [GtkCallback]
        private void video_framerate_commit_edit () {
            int items = video_framerate_entry.text.scanf ("%d / %d",
                out video_framerate_num,
                out video_framerate_den);

            if (items == 1) video_framerate_den = 1;

            video_framerate_entry.text = @"$video_framerate_num / $video_framerate_den";
        }

        [GtkCallback]
        private bool video_framerate_commit_edit_fout () {
            video_framerate_commit_edit();
            return true;
        }
    }
}
