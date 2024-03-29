/* window.vala
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
	[GtkTemplate (ui = "/standalone/glassroom/GlassRoom/window.ui")]
	public class Window : Gtk.ApplicationWindow {

	    static construct {
	        typeof (RecordHeaderBox).ensure();
	        typeof (RecordOptionView).ensure();
	    }

        public Gst.Video.Sink view_sink {get; }
        [GtkChild(name="content-pane")]
        private Gtk.Paned content_pane;

	    private Gtk.Widget view_widget;


        // Sources section.
	    [GtkChild(name="sources-page-stack")]
	    private Gtk.Stack sources_page_stack;

	    [GtkChild(name="sources-header-stack")]
	    private Gtk.Stack sources_header_stack;

        [GtkChild(name="sources-back-reveal")]
        private Gtk.Revealer sources_back_reveal;

        // Sources page 1: Sources List.
        [GtkChild(name="sources-list-box")]
        private Gtk.ListBox sources_list_box;

        [GtkChild(name="sources-list-header-box")]
        private Gtk.Box sources_list_header_box;

        // Sources page 2: Source editing.
        [GtkChild(name="sources-edit")]
        private GlassRoom.SrcBinEdit sources_edit;

        [GtkChild(name="sources-edit-header-box")]
        private Gtk.Box sources_edit_header_box;


        // View section.
        [GtkChild(name="view-page-stack")]
        private Gtk.Stack view_page_stack;

        [GtkChild(name="view-headerbar")]
        private Gtk.HeaderBar view_headerbar;

        [GtkChild(name="view-back-reveal")]
        private Gtk.Revealer view_back_reveal;

        [GtkChild(name="view-header-record-box")]
        private GlassRoom.RecordHeaderBox view_header_record_box;

        [GtkChild(name="view-record-option-view")]
        private GlassRoom.RecordOptionView view_record_option_view;

	    construct {
            GLib.SimpleAction action_sources_back = new GLib.SimpleAction ("sources-back", null);
            action_sources_back.activate.connect (activate_sources_back);

            GLib.SimpleAction action_sources_add = new GLib.SimpleAction ("sources-add", null);
            action_sources_add.activate.connect (activate_sources_add);

            GLib.SimpleAction action_sources_edit_delete = new GLib.SimpleAction ("sources-edit-delete", null);
            action_sources_edit_delete.activate.connect (activate_sources_edit_delete);

            GLib.SimpleAction action_view_back = new GLib.SimpleAction ("view-back", null);
            action_view_back.activate.connect (activate_view_back);

            GLib.SimpleAction action_view_edit_record_option = new GLib.SimpleAction ("view-edit-record-option", null);
            action_view_edit_record_option.activate.connect (activate_edit_record_option);

            add_action(action_sources_back);
            add_action(action_sources_add);
            add_action(action_sources_edit_delete);
            add_action(action_view_back);
            add_action(action_view_edit_record_option);


	        _view_sink = Gst.ElementFactory.make ("gtksink", "view-sink") as Gst.Video.Sink;
	        if (_view_sink == null) {
	            critical ("gtksink is not available on system.");
	        }

            else {
                _view_sink.get ("widget", out view_widget);
                view_page_stack.add_named (view_widget, "preview");
                view_widget.show();
                view_page_stack.child_set (view_widget, "position", 0);
                view_page_stack.visible_child = view_widget;
            }
	    }

		public Window (Gtk.Application app) {
			Object (application: app);
            GlassRoom.Application ga = (GlassRoom.Application) app;
            sources_list_box.bind_model (ga.sources, make_row_for_sources_list_box);

            view_header_record_box.application = ga;
            view_record_option_view.application = ga;
		}

		private Gtk.Widget make_row_for_sources_list_box (Object object) {
            GlassRoom.SrcBin src_bin = (GlassRoom.SrcBin) object;

            return new SrcBinRow (src_bin);
		}


		public void back_sources () {
            sources_edit.src_bin = null;

            sources_page_stack.visible_child = sources_list_box;
            sources_header_stack.visible_child = sources_list_header_box;
            sources_back_reveal.reveal_child = false;
		}

		public void edit_sources (GlassRoom.SrcBin src_bin) {
            sources_edit.src_bin = src_bin;

            sources_page_stack.visible_child = sources_edit;
            sources_header_stack.visible_child = sources_edit_header_box;
            sources_back_reveal.reveal_child = true;
		}


		public void back_view () {
		    if (view_page_stack.visible_child == view_record_option_view) {
		        view_record_option_view.apply_profile();
		    }

		    view_page_stack.visible_child = view_widget;
		    view_back_reveal.reveal_child = false;
		}

		public void edit_record_option () {
		    view_page_stack.visible_child = view_record_option_view;
		    view_back_reveal.reveal_child = true;
		}



		private void activate_sources_back (Variant? parameter) {
		    back_sources();
		}

		private void activate_sources_add (Variant? parameter) {
            GlassRoom.Application ga = (GlassRoom.Application) application;
            edit_sources (ga.add_source());
		}

	    private void activate_sources_edit_delete (Variant? parameter) {
		    GlassRoom.SrcBin subject = sources_edit.src_bin;
		    back_sources();

		    sources_edit.src_bin = null;

            GlassRoom.Application ga = (GlassRoom.Application) application;
            ga.remove_source (subject);
	    }

	    private void activate_view_back (Variant? parameter) {
	        back_view ();
	    }

	    private void activate_edit_record_option (Variant? parameter) {
	        edit_record_option ();
	    }

	    private void on_application_state_change (Object obj, GLib.ParamSpec pspec) {
	        GlassRoom.Application ga = (GlassRoom.Application) obj;

            // If recording, then title should be file name.
            // Subtitle should be
            if (ga.recording) {
                if (ga.pausing) {

                }
            }
	    }
	}
}
