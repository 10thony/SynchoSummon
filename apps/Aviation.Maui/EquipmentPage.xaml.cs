using Aviation.Maui.Services;

namespace Aviation.Maui;

public partial class EquipmentPage : ContentPage
{
    private readonly EquipmentViewModel _viewModel;

    public EquipmentPage(EquipmentViewModel viewModel)
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
