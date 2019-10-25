/* recordheaderbox.vala
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
	[GtkTemplate (ui = "/standalone/glassroom/GlassRoom/recordheaderbox.ui")]
    public class RecordHeaderBox: Gtk.Box {
        private GlassRoom.Application _application;

        private ulong recording_handler;
        private ulong pausing_handler;
        private GLib.TimeoutSource? record_time_src;

        [GtkChild]
        private Gtk.Revealer subtitle_revealer;

        [GtkChild]
        private Gtk.Image subtitle_image;

        [GtkChild]
        private Gtk.Label subtitle_label;


        [GtkChild]
        private Gtk.Label record_label;

        [GtkChild]
        private Gtk.Image record_image;

        [GtkChild]
        private Gtk.Revealer record_as_revealer;

        [GtkChild]
        private Gtk.Revealer pause_revealer;

        public GlassRoom.Application application {
            get {
                return _application;
            }
            set {
                if (_application != null) {
                    _application.disconnect (recording_handler);
                    _application.disconnect (pausing_handler);
                }

                _application = value;

                if (_application != null) {
                    // Register some signals.
                    recording_handler = _application.notify["recording"].connect (on_recording_changed);
                    pausing_handler = _application.notify["pausing"].connect (on_pausing_changed);

                    on_recording_changed ();
                    on_pausing_changed ();
                }
            }
        }

        private void on_recording_changed () {
            bool recording = _application.recording;

            record_as_revealer.reveal_child = ! recording;
            pause_revealer.reveal_child = recording;
            subtitle_revealer.reveal_child = recording;

            record_label.label = (recording) ? "Stop" : "Record";
            record_image.icon_name = (recording) ? "media-playback-stop-symbolic" : "media-record-symbolic";
        }

        private void on_pausing_changed () {
            bool pausing = _application.pausing;

            subtitle_image.icon_name = (pausing) ? "media-playback-pause-symbolic" : "media-record-symbolic";

            if (! pausing) {
                record_time_src = new GLib.TimeoutSource (33);
                record_time_src.set_callback (() => {
                    Gst.ClockTime recording_duration = _application.recording_duration;

                    int total_seconds = (int) (recording_duration / Gst.SECOND);

                    int seconds = total_seconds % 60;
                    int minutes = (total_seconds % 3600) / 60;
                    int hours = total_seconds / 3600;

                    int msecs = (int)(recording_duration / Gst.MSECOND) % 1000;

                    subtitle_label.label = "%02d:%02d:%02d.%03d".printf (hours, minutes, seconds, msecs);
                    return true;
                });
                record_time_src.attach();
            }
            else if (record_time_src != null) {
                record_time_src.destroy();
                record_time_src = null;
            }
        }

        [GtkCallback]
	    private void on_record_as_dialog_response (Gtk.Dialog dialog, int response_id) {
            dialog.hide ();

            if (response_id == Gtk.ResponseType.OK) {
                Gtk.FileChooser chooser = (Gtk.FileChooser) dialog;
                GLib.File file = chooser.get_file();

                application.record (file.get_path());
            }
	    }
    }
}
