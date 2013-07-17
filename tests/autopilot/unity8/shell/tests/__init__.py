# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
# Copyright 2013 Canonical
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.

"""unity8 autopilot tests."""

from autopilot.platform import model
from autopilot.testcase import AutopilotTestCase
from autopilot.matchers import Eventually
from testtools.matchers import Equals, NotEquals
from autopilot.input import Touch
from autopilot.display import Display
import logging
import os.path
import sysconfig

from unity8 import get_lib_path, get_unity8_binary_path
from unity8.shell.emulators.main_window import MainWindow
from unity8.shell.emulators import Unity8EmulatorBase
from unity8.shell.emulators.dash import Dash


logger = logging.getLogger(__name__)


class FormFactors(object):
    Phone, Tablet, Desktop = range(3)

def _get_device_emulation_scenarios():
    if model() == 'Desktop':
        # return [ ('Desktop Nexus 4', dict(app_width=384, app_height=640, grid_unit_px=18)) ]
        return [ ('Desktop Nexus 4', dict(app_width=768, app_height=1280, grid_unit_px=18)) ]
    else:
        return [ ('Native Device', dict(app_width=0, app_height=0, grid_unit_px=0)) ]

class Unity8TestCase(AutopilotTestCase):

    """A sane test case base class for the Unity8 shell tests."""

    def setUp(self):
        super(Unity8TestCase, self).setUp()
        self._proxy = None
        self.touch = Touch.create()
        self._setup_display_details()

    def _setup_display_details(self):
        # This needs a bit of a cleanup, make it clearer
        scale_divisor = self._determine_geometry()
        self._setup_grid_size(scale_divisor)

    def _determine_geometry(self):
        """Use the geometry that may be supplied or use the default."""
        width = getattr(self, 'app_width', 0)
        height = getattr(self, 'app_height', 0)
        scale_divisor = 1
        if width == 0 and width == 0:
            self.unity_geometry_args = ['-fullscreen']
        else:
            if self._geo_larger_than_display(width, height):
                scale_divisor = self._get_scaled_down_geo(width, height)
                width = width / scale_divisor
                height = height / scale_divisor
                logger.info("Provided geometry larger than Display, scaled down to: %sx%s",
                    width,
                    height
                )
            geo_string = "%sx%s" % (width, height)
            self.unity_geometry_args = ['-geometry', geo_string, '-frameless', '-mousetouch']
        return scale_divisor

    def _setup_grid_size(self, scale_divisor):
        """Use the grid size that may be supplied or use the default."""
        if getattr(self, 'grid_unit_px', 0) == 0:
            self.grid_size = int(os.getenv('GRID_UNIT_PX'))
        else:
            self.grid_size = int(self.grid_unit_px / scale_divisor)
            self.patch_environment("GRID_UNIT_PX", str(self.grid_size))

    def _geo_larger_than_display(self, width, height):
        screen = Display.create()
        screen_width = screen.get_screen_width()
        screen_height = screen.get_screen_height()
        return (width > screen_width) or (height > screen_height)

    def _get_scaled_down_geo(self, width, height):
        divisor = 1
        while self._geo_larger_than_display(width / divisor, height / divisor):
            divisor = divisor * 2
        return divisor

    def launch_unity(self):
        """Launch the unity8 shell, return a proxy object for it."""
        # first, work out which binary to launch:
        binary_path = get_unity8_binary_path()
        lib_path = get_lib_path()

        logger.info("Lib path is '%s', binary path is '%s'",
            lib_path,
            binary_path
        )

        # we now have a path to the unity8 binary, and lib_path points to the
        # directory where we need to patch some environment variables.

        # do the environment variable patching:
        self._patch_environment(lib_path)

        # launch the shell:
        app_proxy = self.launch_test_application(
            binary_path,
            *self.unity_geometry_args,
            app_type='qt',
            emulator_base=Unity8EmulatorBase
        )
        logger.debug("Started unity8 shell, backend is: %r", app_proxy._Backend)
        self._set_proxy(app_proxy)

        # Ensure that the dash is visible before we return:
        logger.info("Waiting for the dash to load...")
        self.assertThat(self.get_dash().showScopeOnLoaded, Eventually(Equals("")))
        logger.info("dash loaded!")
        return app_proxy

    def _patch_environment(self, lib_path):
        """Patch environment variables for launching the unity8 shell."""
        # ld_lib_path_patches = (
        #     os.path.join(lib_path, "qml/mocks/libusermetrics"),
        #     os.path.join(lib_path, "qml/mocks/LightDM/" + self.lightdm_mock),
        #     )

        # self.patch_environment("LD_LIBRARY_PATH", ":".join(ld_lib_path_patches))
        self.patch_environment("QML2_IMPORT_PATH", os.path.join(lib_path, "qml/mocks"))

    def _set_proxy(self, proxy):
        """Keep a copy of the proxy object, so we can use it to get common parts
        of the shell later on.

        """
        self._proxy = proxy
        self.addCleanup(self._clear_proxy)

    def _clear_proxy(self):
        self._proxy = None

    def get_dash(self):
        dash = self._proxy.select_single(Dash)
        self.assertThat(dash, NotEquals(None))
        return dash

    @property
    def main_window(self):
        return MainWindow(self._proxy)


class ShellTestCase(AutopilotTestCase):

    """A common test case class that provides several useful methods for shell tests."""

    libdir = "/usr/lib/{0}/unity8".format(sysconfig.get_config_var('MULTIARCH'))
    lightdm_mock = "full"

    def setUp(self, geometry, grid_size):
        super(ShellTestCase, self).setUp()
        # Lets assume we are installed system wide if this file is somewhere in /usr
        if grid_size != "0":
            os.environ['GRID_UNIT_PX'] = grid_size
            self.grid_size = int(grid_size)
        else:
            self.grid_size = int(os.environ['GRID_UNIT_PX'])
        # launch the local binary if it exists, system binary otherwise
        local_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "../../../../../builddir/unity8"
                )
            )
        if os.path.exists(local_path):
            self.launch_test_local(geometry)
        else:
            self.launch_test_installed(geometry)

    def launch_test_local(self, geometry):
        # TODO: This assumed we're launching the tests from the autopilot test root
        # dir, which may not always be the case.
        os.environ['LD_LIBRARY_PATH'] = "../../builddir/tests/mocks/libusermetrics:../../builddir/tests/mocks/LightDM" + self.lightdm_mock
        os.environ['QML2_IMPORT_PATH'] = "../../builddir/tests/mocks"
        if geometry != "0x0":
            self.app = self.launch_test_application(
                "../../builddir/unity8", "-geometry", geometry, "-frameless", app_type='qt')
        else:
            self.app = self.launch_test_application(
                "../../builddir/unity8", "-fullscreen", app_type='qt')

    def launch_test_installed(self, geometry):
        os.environ['LD_LIBRARY_PATH'] = "{0}/qml/mocks/libusermetrics:{0}/qml/mocks/LightDM/{1}".format(self.libdir, self.lightdm_mock)
        os.environ['QML2_IMPORT_PATH'] = "{0}/qml/mocks".format(self.libdir)
        if model() == 'Desktop' and geometry != "0x0":
            self.app = self.launch_test_application(
               "unity8", "-geometry", geometry, "-frameless", app_type='qt')
        else:
            self.app = self.launch_test_application(
               "unity8", "-fullscreen", app_type='qt')

    def skipWrapper(*args, **kwargs):
        pass

    def form_factor(self):
        return FormFactors.Desktop

    def __getattribute__(self, attr_name):
        attr = object.__getattribute__(self, attr_name);
        if attr_name.startswith("test_"):
            try:
                if self.form_factor() in attr.blacklist:
                    return self.skipWrapper
            except:
                pass
        return attr

    @property
    def main_window(self):
        return MainWindow(self.app)
