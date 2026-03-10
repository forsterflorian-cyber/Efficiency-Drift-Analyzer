import Toybox.Graphics;
import Toybox.Lang;

class EDARenderer {

    private const INVALID_RENDER_VALUE as String = "NaN";
    private const INVALID_PACE_PLACEHOLDER as String = "--:--";
    private const INVALID_HR_PLACEHOLDER as String = "--";

    private function normalizePaceValue(value as String) as String {
        if (value.equals(INVALID_RENDER_VALUE)) {
            return INVALID_PACE_PLACEHOLDER;
        }

        return value;
    }

    private function normalizeHrValue(value as String) as String {
        if (value.equals(INVALID_RENDER_VALUE)) {
            return INVALID_HR_PLACEHOLDER;
        }

        return value;
    }

    function drawHighMem(dc as Graphics.Dc, model as Dictionary) as Void {
        var bgColor = model[:renderBgColor] as Number;
        var fgColor = model[:renderFgColor] as Number;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var paceLabel = model[:paceLabel] as String;
        var expectedPaceLabel = model[:expectedPaceLabel] as String;
        var expectedHrLabel = model[:expectedHrLabel] as String;
        var hrLabel = model[:hrLabel] as String;

        if (width < 180) {
            paceLabel = model[:paceShortLabel] as String;
            expectedPaceLabel = model[:expectedPaceShortLabel] as String;
            expectedHrLabel = model[:expectedHrShortLabel] as String;
            hrLabel = model[:hrShortLabel] as String;
        }

        var fOuter = Graphics.FONT_XTINY;
        var fInner = (height < 140) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var fDrift = (height < 140) ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        if (height > 200) {
            fDrift = Graphics.FONT_NUMBER_MEDIUM;
        }

        var currentPaceValue = normalizePaceValue(model[:currentPaceValue] as String);
        var currentHrValue = normalizeHrValue(model[:currentHrValue] as String);
        dc.drawText(width / 2, height * 0.12, fOuter, paceLabel + currentPaceValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.30, fInner, expectedPaceLabel + (model[:expectedPaceValue] as String), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.48, fDrift, model[:driftLabel] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var statusDetail = model[:renderStatusDetail] as String;
        if (statusDetail != "") {
            dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, statusDetail, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (model[:showModelError] as Boolean) {
            dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, model[:renderModelErrorMessage] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var defaultDetail = model[:defaultDetail] as String?;
            if (defaultDetail != null) {
                dc.drawText(width / 2, height * 0.60, Graphics.FONT_XTINY, defaultDetail, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.drawText(width / 2, height * 0.72, fInner, expectedHrLabel + (model[:expectedHrValue] as String), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.88, fOuter, hrLabel + currentHrValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawLowMem(dc as Graphics.Dc, model as Dictionary) as Void {
        var bgColor = model[:renderBgColor] as Number;
        var fgColor = model[:renderFgColor] as Number;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var fPace = Graphics.FONT_TINY;
        var fDrift = (height < 180) ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        var fHr = Graphics.FONT_TINY;

        var currentPaceValue = normalizePaceValue(model[:currentPaceValue] as String);
        var currentHrValue = normalizeHrValue(model[:currentHrValue] as String);
        dc.drawText(width / 2, height * 0.20, fPace, (model[:paceShortLabel] as String) + currentPaceValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height * 0.50, fDrift, model[:driftLabel] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var statusDetail = model[:renderStatusDetail] as String;
        if (statusDetail != "") {
            dc.drawText(width / 2, height * 0.65, Graphics.FONT_XTINY, statusDetail, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var defaultDetail = model[:defaultDetail] as String?;
            if (defaultDetail != null) {
                dc.drawText(width / 2, height * 0.65, Graphics.FONT_XTINY, defaultDetail, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        dc.drawText(width / 2, height * 0.80, fHr, (model[:hrShortLabel] as String) + currentHrValue, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
