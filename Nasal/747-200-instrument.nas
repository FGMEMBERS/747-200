# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# FLIGHT
# ======

Flight = {};

Flight.new = func {
   var obj = { parents : [Flight,System],

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
   me.inherit_system("/systems/flight");
}

Flight.schedule = func {
   var aglft = 0.0;
   var speedkt = 0.0;

   if( me.itself["root-ctrl"].getChild("spoilers-lever").getValue() == me.SPOILERARM ) {
       aglft = constant.nonil( me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue() );
       speedkt = constant.nonil( me.dependency["airspeed"].getChild("indicated-speed-kt").getValue() );

       # extend spoilers at touch down (also avoids rebound of autoland)
       if( aglft < constantaero.AGLTOUCHFT and speedkt > me.SPOILERSKT ) {
 
           # avoids hard landing (quick fall of nose)
           if( me.dependency["gear"][1].getChild("wow").getValue() or
               me.dependency["gear"][2].getChild("wow").getValue() or
               me.dependency["gear"][3].getChild("wow").getValue() or
               me.dependency["gear"][4].getChild("wow").getValue() ) {
               me.spoilersexport( 1.0 );
           }
       }
   }
}

Flight.spoilersexport = func( step ) {
   var value = me.itself["root-ctrl"].getChild("spoilers-lever").getValue();

   value = value + step * me.SPOILERARM;

   if( value < me.SPOILERRETRACT ) {
       value = me.SPOILERRETRACT;
   }
   elsif( value > me.SPOILEREXTEND ) {
       value = me.SPOILEREXTEND;
   }

   me.itself["root-ctrl"].getChild("spoilers-lever").setValue(value);

   controls.stepSpoilers( step );
}



# =============
# SPEED UP TIME
# =============

DayTime = {};

DayTime.new = func {
   var obj = { parents : [DayTime,System],

               SPEEDUPSEC : 1.0,

               CLIMBFTPMIN : 3500,                                       # maximum climb rate
               MAXSTEPFT : 0.0,                                          # altitude change for step

               lastft : 0.0
         };

   obj.init();

   return obj;
}

DayTime.init = func {
    me.inherit_system("/instrumentation/clock");

    var climbftpsec = me.CLIMBFTPMIN / constant.MINUTETOSECOND;

    me.MAXSTEPFT = climbftpsec * me.SPEEDUPSEC;
}

DayTime.schedule = func {
   var altitudeft = me.noinstrument["altitude"].getValue();
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       var multiplier = 0.0;
       var offsetsec = 0.0;
       var warp = 0.0;
       var stepft = 0.0;
       var maxft = 0.0;
       var minft = 0.0;

       # accelerate day time
       multiplier = speedup - 1;
       offsetsec = me.SPEEDUPSEC * multiplier;
       warp = me.noinstrument["warp"].getValue() + offsetsec; 
       me.noinstrument["warp"].setValue(warp);

       # safety
       stepft = me.MAXSTEPFT * speedup;
       maxft = me.lastft + stepft;
       minft = me.lastft - stepft;

       # too fast
       if( altitudeft > maxft or altitudeft < minft ) {
           me.noinstrument["speed-up"].setValue(1);
       }
   }

   me.lastft = altitudeft;
}
