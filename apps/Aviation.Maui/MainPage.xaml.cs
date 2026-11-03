using Aviation.Maui.Services;

namespace Aviation.Maui;

public partial class MainPage : ContentPage
{
    private readonly FacilityListViewModel _viewModel;
    private readonly MauiSyncBootstrapper _bootstrapper;
    private bool _bootstrapKicked;

    public MainPage(FacilityListViewModel viewModel, MauiSyncBootstrapper bootstrapper)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _bootstrapper = bootstrapper;
        BindingContext = _viewModel;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        // Kick off bootstrap exactly once; it returns immediately so the UI never freezes.
        // Any sync errors land on the status label via ErrorRaised / StatusChanged.
        if (!_bootstrapKicked)
        {
            _bootstrapKicked = true;
            _ = _bootstrapper.StartAsync();
        }

        // Fire-and-forget: show whatever is already on disk, then catch up with the server.
        _ = _viewModel.RefreshAsync();
        _ = _viewModel.PullAndRefreshAsync();
    }

    private async void OnRefreshClicked(object? sender, EventArgs e)
    {
        try
        {
            await _viewModel.PullAndRefreshAsync();
        }
        catch (Exception ex)
        {
            await DisplayAlertAsync("Sync", ex.Message, "OK");
        }
    }

    private async void OnAddClicked(object? sender, EventArgs e)
    {
        try
        {
            await _viewModel.AddFacilityAsync();
        }
        catch (Exception ex)
        {
            await DisplayAlertAsync("Sync", ex.Message, "OK");
        }
    }
}
