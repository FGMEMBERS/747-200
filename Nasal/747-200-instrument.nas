# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ======
# FLIGHT
# ======

Flight = {};

Flight.new = func {
   obj = { parents : [Flight],

           FLIGHTSEC : 1.0,              # refresh rate

           SPOILERSKT : 120.0
         };

   return obj;
};

Flight.schedule = func {
   # extend spoilers at touch down (also avoids rebound of autoland)
   if( !getprop("/controls/flight/spoilers-flight") ) {
       if( getprop("/instrumentation/radio-altimeter/indicated-altitude-ft" ) < Constantaero.AGLTOUCHFT and
           getprop("/instrumentation/airspeed-indicator/indicated-speed-kt" ) > me.SPOILERSKT ) {
           # avoids hard landing (quick fall of nose)
           if( getprop("/gear/gear[1]/wow") or getprop("/gear/gear[2]/wow") or
               getprop("/gear/gear[3]/wow") or getprop("/gear/gear[4]/wow") ) {
               me.spoilersExtend( 1.0 );
           }
       }
   }
}

Flight.spoilersexport = func( step ) {
   if( step > 0 ) {
       me.spoilersExtend( step );
   }
   elsif( step < 0 ) {
       me.spoilersRetract( step );
   }
}

Flight.spoilersRetract = func( step ) {
   if( getprop("/controls/flight/spoilers") == 0.0 ) {
       setprop("/controls/flight/spoilers-flight",constant.TRUE);
   }

   controls.stepSpoilers( step );
}

Flight.spoilersExtend = func( step ) {
   controls.stepSpoilers( step );

   if( getprop("/controls/flight/spoilers-flight") ) {
       setprop("/controls/flight/spoilers-flight",constant.FALSE);
   }
}
