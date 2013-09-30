# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===============================
# GROUND PROXIMITY WARNING SYSTEM
# ===============================

Gpws = {};

Gpws.new = func {
   var obj = { parents : [Gpws,System],

               FLIGHTFT : 2500,
               GEARFT : 500,
               GROUNDFT : 200,

               FLIGHTFPS : -50,
               GROUNDFPS : -15,
               TAXIFPS : -5,                                   # taxi is not null

               GEARDOWN : 1.0
         };

   obj.init();

   return obj;
};

Gpws.init = func {
   me.inherit_system("/instrumentation/gpws");
}

Gpws.red_pull_up = func {
   var result = constant.FALSE;
   var aglft = me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue();
   var verticalfps = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue();
   var gearpos = me.dependency["gear"].getChild("position-norm").getValue();

   if( aglft == nil or verticalfps == nil or gearpos == nil ) {
      result = constant.FALSE;
   }

   # 3000 ft/min
   elsif( aglft < me.FLIGHTFT and verticalfps < me.FLIGHTFPS ) {
       result = constant.TRUE;
   }

   # 900 ft/min
   elsif( aglft < me.GROUNDFT and verticalfps < me.GROUNDFPS ) {
       result = constant.TRUE;
   }

   # gear not down
   elsif( aglft < me.GEARFT and verticalfps < me.TAXIFPS and gearpos < me.GEARDOWN ) {
       result = constant.TRUE;
   }

   return result;
}


# ==============
# WARNING SYSTEM
# ==============

Warning = {};

Warning.new = func {
   var obj = { parents : [Warning,System],

               doorsystem : nil,

               gpwssystem : Gpws.new()
         };

   obj.init();

   return obj;
};

Warning.init = func {
   me.inherit_system("/systems/warning");
}

Warning.set_relation = func( door ) {
   me.doorsystem = door;
}

Warning.schedule = func {
   me.sendamber( "cargo-doors", me.doorsystem.amber_cargo_doors() );

   me.sendred( "pull-up", me.gpwssystem.red_pull_up() );
}

Warning.sendamber = func( name, value ) {
   if( me.itself["amber"].getChild(name).getValue() != value ) {
       me.itself["amber"].getChild(name).setValue( value );
   }
}

Warning.sendred = func( name, value ) {
   if( me.itself["red"].getChild(name).getValue() != value ) {
       me.itself["red"].getChild(name).setValue( value );
   }
}
