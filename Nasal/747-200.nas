# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen (?).



# ==============
# Initialization
# ==============

BoeingMain = {};

BoeingMain.new = func {
   var obj = { parents : [BoeingMain]
         };

   obj.init();

   return obj;
}

BoeingMain.putinrelation = func {
   autopilotsystem.set_relation( autothrottlesystem );
   warningsystem.set_relation( doorsystem, enginesystem, gearsystem );
   
   crewcrew.set_relation( autopilotsystem, flightsystem, fuelsystem );
}

BoeingMain.statecron = func {
   crewcrew.startupexport();
}

# 1 s cron
BoeingMain.sec1cron = func {
   flightsystem.schedule();
   fuelsystem.schedule();
   warningsystem.schedule();
   daytimeinstrument.schedule();

   # schedule the next call
   settimer(func{ me.sec1cron(); },1);
}

# 2 s cron
BoeingMain.sec2cron = func {
   gearsystem.schedule();

   # schedule the next call
   settimer(func{ me.sec2cron(); },2);
}

# 3 s cron
BoeingMain.sec3cron = func {
   autopilotsystem.schedule();
   autothrottlesystem.schedule();
   INSinstrument.schedule();
   crewscreen.schedule();

   # schedule the next call
   settimer(func{ me.sec3cron(); },crewscreen.MENUSEC);
}

# 5 s cron
BoeingMain.sec5cron = func {
   tractorexternal.schedule();

   # schedule the next call
   settimer(func{ me.sec5cron(); },tractorexternal.TRACTORSEC);
}

# 60 s cron
BoeingMain.sec60cron = func {
   engineercrew.veryslowschedule();

   # schedule the next call
   settimer(func { me.sec60cron(); },60);
}

BoeingMain.savedata = func {
   aircraft.data.add("/controls/autoflight/fg-waypoint");
   aircraft.data.add("/controls/environment/contrails");
   aircraft.data.add("/controls/fuel/reinit");
   aircraft.data.add("/controls/seat/recover");
   aircraft.data.add("/systems/fuel/presets");
   aircraft.data.add("/systems/seat/position/cargo-aft/x-m");
   aircraft.data.add("/systems/seat/position/cargo-aft/y-m");
   aircraft.data.add("/systems/seat/position/cargo-aft/z-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/x-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/y-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/z-m");
   aircraft.data.add("/systems/seat/position/gear-well/x-m");
   aircraft.data.add("/systems/seat/position/gear-well/y-m");
   aircraft.data.add("/systems/seat/position/gear-well/z-m");
   aircraft.data.add("/systems/seat/position/observer/x-m");
   aircraft.data.add("/systems/seat/position/observer/y-m");
   aircraft.data.add("/systems/seat/position/observer/z-m");
}

# global variables in Boeing747 namespace, for call by XML
BoeingMain.instantiate = func {
   globals.Boeing747.constant = Constant.new();
   globals.Boeing747.constantaero = ConstantAero.new();

   globals.Boeing747.autopilotsystem = Autopilot.new();
   globals.Boeing747.autothrottlesystem = Autothrottle.new();
   globals.Boeing747.enginesystem = Engine.new();
   globals.Boeing747.fuelsystem = Fuel.new();
   globals.Boeing747.flightsystem = Flight.new();
   globals.Boeing747.gearsystem = Gear.new();
   globals.Boeing747.warningsystem = Warning.new();

   globals.Boeing747.INSinstrument = Inertial.new();
   globals.Boeing747.daytimeinstrument = DayTime.new();

   globals.Boeing747.doorsystem = Doors.new();
   globals.Boeing747.seatsystem = Seats.new();

   globals.Boeing747.menuscreen = Menu.new();
   globals.Boeing747.crewscreen = Crewbox.new();

   globals.Boeing747.engineercrew = Virtualengineer.new();
   globals.Boeing747.crewcrew = Crew.new();

   globals.Boeing747.tractorexternal = Tractor.new();
}

# initialization
BoeingMain.init = func {
   aircraft.livery.init( "Aircraft/747-200/Models/Liveries",
                         "sim/model/livery/name",
                         "sim/model/livery/index" );

   me.instantiate();
   me.putinrelation();

   # schedule the 1st call
   settimer(func { me.sec1cron(); },0);
   settimer(func { me.sec2cron(); },0);
   settimer(func { me.sec3cron(); },0);
   settimer(func { me.sec5cron(); },0);
   settimer(func { me.sec60cron(); },0);

   # saved on exit, restored at launch
   me.savedata();
   
   # waits that systems are ready
   settimer(func { me.statecron(); },2.0);
}

# state reset
BoeingMain.reinit = func {
   if( getprop("/controls/fuel/reinit") ) {
       # default is JSBSim state, which loses fuel selection.
       globals.Boeing747.fuelsystem.reinitexport();
   }
}


# object creation
boeing747L  = setlistener("/sim/signals/fdm-initialized", func { globals.Boeing747.main = BoeingMain.new(); removelistener(boeing747L); });

# state reset
boeing747L2 = setlistener("/sim/signals/reinit", func { globals.Boeing747.main.reinit(); });
