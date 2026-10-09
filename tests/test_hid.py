"""Tests for the HID report descriptor parser, against descriptors shaped like real Apple displays."""

import os
import unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
loader = SourceFileLoader("studio_brightness", os.path.join(ROOT, "studio-brightness"))
sb = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(sb)

# Studio Display MI_07 as documented by Studio Brightness ++: report 1 carries 32-bit
# brightness (400-60000) followed by a 16-bit field on page 0x0F, usage 0x50.
STUDIO_DISPLAY = bytes([
    0x05, 0x80, 0x09, 0x01, 0xA1, 0x01,        # Monitor page, Monitor Control, collection
    0x85, 0x01,                                # report ID 1
    0x05, 0x82, 0x09, 0x10,                    # VESA controls, Brightness
    0x16, 0x90, 0x01,                          # logical min 400
    0x27, 0x60, 0xEA, 0x00, 0x00,              # logical max 60000
    0x75, 0x20, 0x95, 0x01, 0xB1, 0x02,        # 32 bits x 1, Feature
    0x05, 0x0F, 0x09, 0x50,                    # page 0x0F usage 0x50
    0x15, 0x00, 0x26, 0x20, 0x4E,              # 0-20000
    0x75, 0x10, 0x95, 0x01, 0xB1, 0x02,        # 16 bits x 1, Feature
    0xC0,
])


class FindFeatureField(unittest.TestCase):
    def test_studio_display(self):
        self.assertEqual(sb.find_feature_field(STUDIO_DISPLAY, sb.BRIGHTNESS_USAGE),
                         (1, 8, 32, 400, 60000, 7))

    def test_two_byte_max_read_as_unsigned(self):
        # 0xEA60 is negative as a signed 16-bit value; it must still mean 60000.
        desc = STUDIO_DISPLAY.replace(bytes([0x27, 0x60, 0xEA, 0x00, 0x00]),
                                      bytes([0x26, 0x60, 0xEA]))
        self.assertEqual(sb.find_feature_field(desc, sb.BRIGHTNESS_USAGE)[3:5], (400, 60000))

    def test_field_after_other_feature(self):
        # Brightness second in the report: its offset counts the 16-bit field before it.
        desc = bytes([
            0x05, 0x80, 0x09, 0x01, 0xA1, 0x01, 0x85, 0x02,
            0x05, 0x0F, 0x09, 0x50, 0x15, 0x00, 0x26, 0x20, 0x4E,
            0x75, 0x10, 0x95, 0x01, 0xB1, 0x02,
            0x05, 0x82, 0x09, 0x10, 0x15, 0x00, 0x26, 0xFF, 0x00,
            0x75, 0x08, 0x95, 0x01, 0xB1, 0x02,
            0xC0,
        ])
        self.assertEqual(sb.find_feature_field(desc, sb.BRIGHTNESS_USAGE),
                         (2, 24, 8, 0, 255, 4))

    def test_missing_usage(self):
        audio = bytes([0x05, 0x0C, 0x09, 0x01, 0xA1, 0x01, 0x09, 0xE9, 0x15, 0x00,
                       0x25, 0x01, 0x75, 0x01, 0x95, 0x01, 0x81, 0x02, 0xC0])
        self.assertIsNone(sb.find_feature_field(audio, sb.BRIGHTNESS_USAGE))


class Percent(unittest.TestCase):
    class Display:
        lo, hi = 400, 60000

    def test_round_trip(self):
        d = self.Display()
        for pct in (0, 1, 37, 50, 99, 100):
            self.assertEqual(sb.to_pct(d, sb.from_pct(d, pct)), pct)

    def test_clamps(self):
        d = self.Display()
        self.assertEqual(sb.from_pct(d, -5), 400)
        self.assertEqual(sb.from_pct(d, 150), 60000)


class ParseArgs(unittest.TestCase):
    def test_options_after_command(self):
        # The form the README and install.sh's shortcuts use.
        args = sb.parse_args(["up", "--osd"])
        self.assertEqual((args.cmd, args.step, args.osd, args.notify), ("up", 10, True, False))

    def test_options_before_command(self):
        args = sb.parse_args(["--notify", "-d", "hidraw3", "down", "5"])
        self.assertEqual((args.cmd, args.step, args.notify, args.display),
                         ("down", 5.0, True, ["hidraw3"]))

    def test_defaults(self):
        args = sb.parse_args(["list"])
        self.assertEqual((args.display, args.notify, args.osd), (None, False, False))

    def test_negative_value_is_not_an_option(self):
        self.assertEqual(sb.parse_args(["set", "-10", "--osd"]).value, "-10")


if __name__ == "__main__":
    unittest.main()
