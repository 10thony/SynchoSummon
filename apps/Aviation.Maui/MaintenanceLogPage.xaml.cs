using Aviation.Maui.Services;

namespace Aviation.Maui;

public partial class MaintenanceLogPage : ContentPage
{
    private readonly MaintenanceLogViewModel _viewModel;

    public MaintenanceLogPage(MaintenanceLogViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        BindingContext = _viewModel;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();
        _ = _viewModel.RefreshAsync();
    }
}
