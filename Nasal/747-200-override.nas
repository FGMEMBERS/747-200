# WARNING :
# - nasal overriding may not work on some platforms (Cygwin).
# - put all code in comment to recover the default behaviour.


# ========================
# OVERRIDING NASAL GLOBALS
# ========================


# override flaps controls, to trigger the leading edge flaps
override_flapsDown = controls.flapsDown;

controls.flapsDown = func( step ) {
   flapspos = constant.nonil( getprop("/controls/flight/flaps") );

   # only flaps 1 and 5 deg
   if( flapspos < getprop("/sim/flaps/setting[3]") ) {
       # uses slats interface
       controls.stepSlats( step );

       # no FG interface with JSBSim
       setprop( "/fdm/jsbsim/fcs/LE-flap-cmd-norm", getprop("/controls/flight/slats") );
   }

   override_flapsDown( step );
}
