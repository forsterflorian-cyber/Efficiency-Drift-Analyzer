import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class EDAApp extends Application.AppBase {

    // Explizite Typisierung für den strict mode
    private var mView as EDAView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        mView = null;
    }

    function getInitialView() as [ Views ] or [ Views, InputDelegates ] {
        var view = new EDAView();
        mView = view;
        return [ view ];
    }

    function onSettingsChanged() as Void {
        var view = mView;
        if (view != null) {
            view.applySettingsChange();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as EDAApp {
    return Application.getApp() as EDAApp;
}
