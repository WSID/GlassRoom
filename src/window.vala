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

	    construct {
	        _view_sink = Gst.ElementFactory.make ("gtksink", "view-sink") as Gst.Video.Sink;
	        if (_view_sink == null) {
	            critical ("gtksink is not available on system.");
	        }

            else {
                _view_sink.get ("widget", out view_widget);
                content_pane.add (view_widget);
                view_widget.show();
            }

	    }

		public Window (Gtk.Application app) {
			Object (application: app);
            GlassRoom.Application ga = (GlassRoom.Application) app;
            sources_list_box.bind_model (ga.sources, make_row_for_sources_list_box);
		}

        [GtkCallback]
		private void on_sources_add_clicked () {
            GlassRoom.Application ga = (GlassRoom.Application) application;
            edit_sources (ga.add_source());
		}

		[GtkCallback]
		private void on_sources_back_clicked () {
		    back_sources ();
		}

		private Gtk.Widget make_row_for_sources_list_box (Object object) {
            GlassRoom.SrcBin src_bin = (GlassRoom.SrcBin) object;

            return new SrcBinRow (src_bin);
		}

		private void back_sources () {
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

        [GtkCallback]
		private void edit_delete_sources () {
		    GlassRoom.SrcBin subject = sources_edit.src_bin;
		    back_sources();

            GlassRoom.Application ga = (GlassRoom.Application) application;
            ga.remove_source (subject);
		}
	}
}
