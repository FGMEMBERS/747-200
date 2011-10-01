# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# FLIGHT
# ======

Flight = {};

Flight.new = func {
   var obj = { parents : [Flight],

           flightcontrols : nil,

           FLIGHTSEC : 1.0,              # refresh rate

           SPOILEREXTEND : 1.0,
           SPOILERARM : 0.5,
           SPOILERRETRACT : 0.0,

           SPOILERSKT : 120.0
         };

   obj.init();

   return obj;
};

Flight.init = func {
   me.flightcontrols = props.globals.getNode("/controls/flight");
}

Flight.schedule = func {
   var aglft = 0.0;
   var speedkt = 0.0;

   if( me.flightcontrols.getChild("spoilers-lever").getValue() == me.SPOILERARM ) {
       aglft = constant.nonil( getprop("/instrumentation/radio-altimeter/indicated-altitude-ft") );
       speedkt = constant.nonil( getprop("/instrumentation/airspeed-indicator/indicated-speed-kt" ) );

       # extend spoilers at touch down (also avoids rebound of autoland)
       if( aglft < constantaero.AGLTOUCHFT and speedkt > me.SPOILERSKT ) {
 
           # avoids hard landing (quick fall of nose)
           if( getprop("/gear/gear[1]/wow") or getprop("/gear/gear[2]/wow") or
               getprop("/gear/gear[3]/wow") or getprop("/gear/gear[4]/wow") ) {
               me.spoilersexport( 1.0 );
           }
       }
   }
}

Flight.spoilersexport = func( step ) {
   var value = 0.0;

   value = me.flightcontrols.getChild("spoilers-lever").getValue();
   value = value + step * me.SPOILERARM;

   if( value < me.SPOILERRETRACT ) {
       value = me.SPOILERRETRACT;
   }
   elsif( value > me.SPOILEREXTEND ) {
       value = me.SPOILEREXTEND;
   }

   me.flightcontrols.getChild("spoilers-lever").setValue(value);

   controls.stepSpoilers( step );
}



# =============
# SPEED UP TIME
# =============

DayTime = {};

DayTime.new = func {
   var obj = { parents : [DayTime],

           altitudenode : nil,
           thesim : nil,
           warpnode : nil,

           SPEEDUPSEC : 1.0,

           CLIMBFTPMIN : 3500,                                       # maximum climb rate
           MAXSTEPFT : 0.0,                                          # altitude change for step

           lastft : 0.0
         };

   obj.init();

   return obj;
}

DayTime.init = func {
    var climbftpsec = me.CLIMBFTPMIN / constant.MINUTETOSECOND;

    me.MAXSTEPFT = climbftpsec * me.SPEEDUPSEC;

    me.altitudenode = props.globals.getNode("/position/altitude-ft");
    me.thesim = props.globals.getNode("/sim");
    me.warpnode = props.globals.getNode("/sim/time/warp");
}

DayTime.schedule = func {
   var altitudeft = 0.0;
   var speedup = 1.0;
   var multiplier = 0.0;
   var offsetsec = 0.0;
   var warpi = 0.0;
   var stepft = 0.0;
   var maxft = 0.0;
   var minft = 0.0;

   altitudeft = me.altitudenode.getValue();

   speedup = me.thesim.getChild("speed-up").getValue();
   if( speedup > 1 ) {
       # accelerate day time
       multiplier = speedup - 1;
       offsetsec = me.SPEEDUPSEC * multiplier;
       warp = me.warpnode.getValue() + offsetsec; 
       me.warpnode.setValue(warp);

       # safety
       stepft = me.MAXSTEPFT * speedup;
       maxft = me.lastft + stepft;
       minft = me.lastft - stepft;

       # too fast
       if( altitudeft > maxft or altitudeft < minft ) {
           me.thesim.getChild("speed-up").setValue(1);
       }
   }

   me.lastft = altitudeft;
}
