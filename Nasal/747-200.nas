# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen (?).



# ==============
# Initialization
# ==============

putinrelation = func {
   autopilotsystem.set_relation( autothrottlesystem );
}

# 1 s cron
sec1cron = func {
   autopilotsystem.schedule();
   flightsystem.schedule();

   # schedule the next call
   settimer(sec1cron,autopilotsystem.AUTOPILOTSEC);
}

# 2 s cron
sec2cron = func {
   fuelsystem.schedule();
   autothrottlesystem.schedule();

   # schedule the next call
   settimer(sec2cron,fuelsystem.SPEEDUPSEC);
}

# initialization
init = func {
   putinrelation();

   # schedule the 1st call
   sec1cron();
   sec2cron();
}

# objects must be here, otherwise local to init()
constant = Constant.new();
Constantaero = ConstantAero.new();
autopilotsystem = Autopilot.new();
autothrottlesystem = Autothrottle.new();
fuelsystem = Fuel.new();
flightsystem = Flight.new();

doorsystem = Doors.new();
seatsystem = Seats.new();
menusystem = Menu.new();

setlistener("/sim/signals/fdm-initialized", init);
