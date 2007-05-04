# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =====
# SEATS
# =====

Seats = {};

Seats.new = func {
   obj = { parents : [Seats],

           theseats : nil,

           lookup : { "gear-well" : 0, "cargo-aft" : 1, "cargo-forward" : 2 },
           names : [ "gear-well", "cargo-aft", "cargo-forward" ],
           nb_seats : 3,

           initial : { "cargo-aft" : {"x" : 0, "y" : 0, "z" : 0 },
                       "cargo-forward" : {"x" : 0, "y" : 0, "z" : 0 },
                       "gear-well" : { "x" : 0, "y" : 0, "z" : 0 } }
         };

   obj.init();

   return obj;
};

Seats.init = func {
   me.theseats = props.globals.getNode("/systems/seat");

   theviews = props.globals.getNode("/sim").getChildren("view");
   last = size(theviews);

   # retrieve the index as created by FG
   for( i = 0; i < last; i=i+1 ) {
        child = theviews[i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Gear Well View" ) {
                me.lookup["gear-well"] = i;
                me.save_position( "gear-well", theviews[i] );
            }
            elsif( name == "Cargo Aft View" ) {
                me.lookup["cargo-aft"] = i;
                me.save_position( "cargo-aft", theviews[i] );
            }
            elsif( name == "Cargo Forward View" ) {
                me.lookup["cargo-forward"] = i;
                me.save_position( "cargo-forward", theviews[i] );
            }
        }
   }
}

Seats.viewexport = func( name ) {
   if( name != "captain" ) {

       # swap to view
       if( !me.theseats.getChild(name).getValue() ) {
           index = me.lookup[name];
           setprop("/sim/current-view/view-number", index);
           me.theseats.getChild(name).setValue(constant.TRUE);
           me.theseats.getChild("captain").setValue(constant.FALSE);
       }

       # return to captain view
       else {
           setprop("/sim/current-view/view-number", 0);
           me.theseats.getChild(name).setValue(constant.FALSE);
           me.theseats.getChild("captain").setValue(constant.TRUE);
       }

       # disable all other views
       for( i = 0; i < me.nb_seats; i=i+1 ) {
            if( name != me.names[i] ) {
                me.theseats.getChild(me.names[i]).setValue(constant.FALSE);
            }
       }
   }

   # captain view
   else {
       setprop("/sim/current-view/view-number",0);
       me.theseats.getChild("captain").setValue(constant.TRUE);

        # disable all other views
        for( i = 0; i < me.nb_seats; i=i+1 ) {
             me.theseats.getChild(me.names[i]).setValue(constant.FALSE);
        }
   }
}

Seats.scrollexport = func{
   # number of views = 11
   nbviews = size(props.globals.getNode("/sim").getChildren("view"));

   # by default, returns to captain view
   targetview = nbviews;

   # if specific view, step once more to ignore captain view 
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # number of default views (preferences.xml) = 6
   nbdefaultviews = nbviews - me.nb_seats;

   # last default view (preferences.xml) = 5
   lastview = nbdefaultviews - 1;

   # moves to seat
   if( getprop("/sim/current-view/view-number") == lastview ) {
       step = targetview - nbdefaultviews;
       view.stepView(step);
       view.stepView(1);
   }

   # returns to captain
   elsif( getprop("/sim/current-view/view-number") == targetview ) {
       step = nbviews - targetview;
       view.stepView(step);
       view.stepView(1);
   }

   # default
   else {
       view.stepView(1);
   }
}

Seats.scrollreverseexport = func{
   # number of views = 11
   nbviews = size(props.globals.getNode("/sim").getChildren("view"));

   # by default, returns to captain view
   targetview = 0;

   # if specific view, step once more to ignore captain view 
   for( i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.theseats.getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # number of default views (preferences.xml) = 6
   nbdefaultviews = nbviews - me.nb_seats;

   # last view = 10
   lastview = nbviews - 1;

   # moves to seat
   if( getprop("/sim/current-view/view-number") == 1 ) {
       # to 0
       view.stepView(-1);
       # to last
       view.stepView(-1);
       step = targetview - lastview;
       view.stepView(step);
    }

   # returns to captain
    elsif( getprop("/sim/current-view/view-number") == targetview ) {
        step = nbdefaultviews - targetview;
        view.stepView(step);
        view.stepView(-1);
    }

    # default
    else {
        view.stepView(-1);
    }
}

# forwards is positiv
Seats.movelengthexport = func( step ) {
   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       else {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# left is negativ
Seats.movewidthexport = func( step ) {
   if( me.move() ) {
       headdeg = getprop("/sim/current-view/goal-heading-offset-deg");

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "/sim/current-view/x-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "/sim/current-view/z-offset-m";
           sign = 1;
       }
       else {
           prop = "/sim/current-view/z-offset-m";
           sign = -1;
       }

       pos = getprop(prop);
       pos = pos + sign * step;
       setprop(prop,pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# up is positiv
Seats.moveheightexport = func( step ) {
   if( me.move() ) {
       pos = getprop("/sim/current-view/y-offset-m");
       pos = pos + step;
       setprop("/sim/current-view/y-offset-m",pos);

       result = constant.TRUE;
   }

   else {
       result = constant.FALSE;
   }

   return result;
}

# backup initial position
Seats.save_position = func( name, view ) {
   config = view.getNode("config");
   me.initial[name]["x"] = config.getChild("x-offset-m").getValue();
   me.initial[name]["y"] = config.getChild("y-offset-m").getValue();
   me.initial[name]["z"] = config.getChild("z-offset-m").getValue();
}

Seats.restore_position = func( name ) {
   setprop("/sim/current-view/x-offset-m",me.initial[name]["x"]);
   setprop("/sim/current-view/y-offset-m",me.initial[name]["y"]);
   setprop("/sim/current-view/z-offset-m",me.initial[name]["z"]);
}

Seats.move = func {
   if( me.theseats.getChild("cargo-aft").getValue() or
       me.theseats.getChild("cargo-forward").getValue() or
       me.theseats.getChild("gear-well").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   if( me.theseats.getChild("cargo-aft").getValue() ) {
       me.restore_position( "cargo-aft" );
   }
   elsif( me.theseats.getChild("cargo-forward").getValue() ) {
       me.restore_position( "cargo-forward" );
   }
   elsif( me.theseats.getChild("gear-well").getValue() ) {
       me.restore_position( "gear-well" );
   }
}


# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   obj = { parents : [Doors],

           cargobulk : aircraft.door.new("controls/doors/cargo/bulk", 12.0),
           cargoaft : aircraft.door.new("controls/doors/cargo/aft", 12.0),
           cargoforward : aircraft.door.new("controls/doors/cargo/forward", 12.0)
         };
   return obj;
};

Doors.cargobulkexport = func {
   me.cargobulk.toggle();
}

Doors.cargoaftexport = func {
   me.cargoaft.toggle();
}

Doors.cargoforwardexport = func {
   me.cargoforward.toggle();
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   obj = { parents : [Menu],

           crew : nil,
           fuel : nil,
           radios : nil,
           menu : nil
         };

   obj.init();

   return obj;
};

Menu.init = func {
   # B747-200, because property system refuses 747-200
   me.menu = gui.Dialog.new("/sim/gui/dialogs/B747-200/menu/dialog",
                            "Aircraft/747-200/Dialogs/747-200-menu.xml");
   me.crew = gui.Dialog.new("/sim/gui/dialogs/B747-200/crew/dialog",
                            "Aircraft/747-200/Dialogs/747-200-crew.xml");
   me.fuel = gui.Dialog.new("/sim/gui/dialogs/B747-200/fuel/dialog",
                            "Aircraft/747-200/Dialogs/747-200-fuel.xml");
   me.radios = gui.Dialog.new("/sim/gui/dialogs/B747-200/radios/dialog",
                            "Aircraft/747-200/Dialogs/747-200-radios.xml");
}
