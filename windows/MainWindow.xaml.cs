using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using aathoos.Views;
using Windows.Graphics;

namespace aathoos;

public sealed partial class MainWindow : Window
{
  public MainWindow()
  {
    InitializeComponent();
    Title = "aathoos";

    // Set initial window size to 1100x700
    AppWindow.Resize(new SizeInt32(1100, 700));

    // Navigate to Dashboard on launch
    NavView.SelectedItem = NavView.MenuItems[0];
    ContentFrame.Navigate(typeof(DashboardPage));
  }

  private void NavView_SelectionChanged(
    NavigationView sender,
    NavigationViewSelectionChangedEventArgs args)
  {
    if (args.SelectedItem is not NavigationViewItem item) return;

    Type? page = item.Tag?.ToString() switch
    {
      "dashboard"    => typeof(DashboardPage),
      "tasks"        => typeof(TasksPage),
      "notes"        => typeof(NotesPage),
      "studyplanner" => typeof(StudyPlannerPage),
      "goals"        => typeof(GoalsPage),
      "focusmode"    => typeof(FocusModePage),
      _              => null,
    };

    if (page is not null)
      ContentFrame.Navigate(page);
  }
}
