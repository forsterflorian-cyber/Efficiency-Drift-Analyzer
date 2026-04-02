import Toybox.Graphics;
import Toybox.Lang;

class EDARenderer {

    private const ELLIPSIS as String = "...";
    private const TEXT_HORIZONTAL_PADDING as Number = 6;

    private function getTextBudget(width as Number) as Number {
        var budget = width - (TEXT_HORIZONTAL_PADDING * 2);
        if (budget < 0) {
            return 0;
        }

        return budget;
    }

    private function selectTextToFit(dc as Graphics.Dc, text as String?, fallbackText as String?, font as Graphics.FontType, maxWidth as Number) as String {
        if (text == null) {
            return "";
        }

        var primaryText = text as String;
        if (primaryText == "") {
            return "";
        }

        if (dc.getTextWidthInPixels(primaryText, font) <= maxWidth) {
            return primaryText;
        }

        if (fallbackText != null) {
            var shortText = fallbackText as String;
            if (shortText != "" && !shortText.equals(primaryText)) {
                if (dc.getTextWidthInPixels(shortText, font) <= maxWidth) {
                    return shortText;
                }
            }
        }

        if (dc.getTextWidthInPixels(ELLIPSIS, font) <= maxWidth) {
            return ELLIPSIS;
        }

        return "";
    }

    private function drawResponsiveText(dc as Graphics.Dc, width as Number, y as Numeric, font as Graphics.FontType, text as String?, fallbackText as String?) as Void {
        var renderText = selectTextToFit(dc, text, fallbackText, font, getTextBudget(width));
        if (renderText == "") {
            return;
        }

        dc.drawText(width / 2, y, font, renderText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawHighMem(dc as Graphics.Dc, model as Dictionary) as Void {
        var bgColor = model[:renderBgColor] as Number;
        var fgColor = model[:renderFgColor] as Number;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        var fOuter = Graphics.FONT_XTINY;
        var fInner = (height < 140) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var fDrift = (height < 140) ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        if (height > 200) {
            fDrift = Graphics.FONT_NUMBER_MEDIUM;
        }

        drawResponsiveText(dc, width, height * 0.12, fOuter, model[:paceLine] as String, model[:paceShortLine] as String);
        drawResponsiveText(dc, width, height * 0.30, fInner, model[:expectedPaceLine] as String, model[:expectedPaceShortLine] as String);
        drawResponsiveText(dc, width, height * 0.48, fDrift, model[:driftLine] as String, model[:driftShortLine] as String?);

        var statusDetail = model[:renderStatusDetailLine] as String;
        if (statusDetail != "") {
            drawResponsiveText(dc, width, height * 0.60, Graphics.FONT_XTINY, statusDetail, model[:renderStatusDetailShortLine] as String?);
        } else if (model[:showModelError] as Boolean) {
            drawResponsiveText(dc, width, height * 0.60, Graphics.FONT_XTINY, model[:renderModelErrorLine] as String, null);
        } else {
            var defaultDetail = model[:defaultDetailLine] as String?;
            if (defaultDetail != null) {
                drawResponsiveText(dc, width, height * 0.60, Graphics.FONT_XTINY, defaultDetail, model[:defaultDetailShortLine] as String?);
            }
        }

        drawResponsiveText(dc, width, height * 0.72, fInner, model[:expectedHrLine] as String, model[:expectedHrShortLine] as String);
        drawResponsiveText(dc, width, height * 0.88, fOuter, model[:hrLine] as String, model[:hrShortLine] as String);
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

        drawResponsiveText(dc, width, height * 0.20, fPace, model[:paceLine] as String, model[:paceShortLine] as String);
        drawResponsiveText(dc, width, height * 0.50, fDrift, model[:driftLine] as String, model[:driftShortLine] as String?);

        var statusDetail = model[:renderStatusDetailLine] as String;
        if (statusDetail != "") {
            drawResponsiveText(dc, width, height * 0.65, Graphics.FONT_XTINY, statusDetail, model[:renderStatusDetailShortLine] as String?);
        } else {
            var defaultDetail = model[:defaultDetailLine] as String?;
            if (defaultDetail != null) {
                drawResponsiveText(dc, width, height * 0.65, Graphics.FONT_XTINY, defaultDetail, model[:defaultDetailShortLine] as String?);
            }
        }

        drawResponsiveText(dc, width, height * 0.80, fHr, model[:hrLine] as String, model[:hrShortLine] as String);
    }
}
