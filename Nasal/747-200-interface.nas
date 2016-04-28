# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =====
# SEATS
# =====

Seats = {};

Seats.new = func {
   var obj = { parents : [Seats,System],

               lookup : {},
               names : {},
               nb_seats : 0,

               CAPTINDEX : 0,

               floating : {},
               recoverfloating : constant.FALSE,
               last_recover : {},
               initial : {}
         };

   obj.init();

   return obj;
};

Seats.init = func {
   var child = nil;
   var name = "";

   me.inherit_system("/systems/seat");

   # retrieve the index as created by FG
   for( var i = 0; i < size(me.dependency["views"]); i=i+1 ) {
        child = me.dependency["views"][i].getChild("name");

        # nasal doesn't see yet the views of preferences.xml
        if( child != nil ) {
            name = child.getValue();
            if( name == "Copilot View" ) {
                me.save_lookup("copilot", i);
            }
            elsif( name == "Engineer View" ) {
                me.save_lookup("engineer", i);
            }
            elsif( name == "Observer View" ) {
                me.save_lookup("observer", i);
                me.save_initial( "observer", me.dependency["views"][i] );
            }
            elsif( name == "Gear Well View" ) {
                me.save_lookup("gear-well", i);
                me.save_initial( "gear-well", me.dependency["views"][i] );
            }
            elsif( name == "Cargo Aft View" ) {
                me.save_lookup("cargo-aft", i);
                me.save_initial( "cargo-aft", me.dependency["views"][i] );
            }
            elsif( name == "Cargo Forward View" ) {
                me.save_lookup("cargo-forward", i);
                me.save_initial( "cargo-forward", me.dependency["views"][i] );
            }
        }
   }

   # default
   me.recoverfloating = me.itself["root-ctrl"].getChild("recover").getValue();
}

Seats.recoverexport = func {
   me.recoverfloating = !me.recoverfloating;
   me.itself["root-ctrl"].getChild("recover").setValue(me.recoverfloating);
}

Seats.viewexport = func( name ) {
   var index = 0;

   if( name != "captain" ) {
       index = me.lookup[name];

       # swap to view
       if( !me.itself["root"].getChild(name).getValue() ) {
           me.dependency["current-view"].getChild("view-number").setValue(index);
           me.itself["root"].getChild(name).setValue(constant.TRUE);
           me.itself["root"].getChild("captain").setValue(constant.FALSE);

           me.dependency["views"][index].getChild("enabled").setValue(constant.TRUE);
       }

       # return to captain view
       else {
           me.dependency["current-view"].getChild("view-number").setValue(0);
           me.itself["root"].getChild(name).setValue(constant.FALSE);
           me.itself["root"].getChild("captain").setValue(constant.TRUE);

           me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
       }

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            if( name != me.names[i] ) {
                me.itself["root"].getChild(me.names[i]).setValue(constant.FALSE);

                index = me.lookup[me.names[i]];
                me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
            }
       }

       me.recover();
   }

   # captain view
   else {
       me.dependency["current-view"].getChild("view-number").setValue(0);
       me.itself["root"].getChild("captain").setValue(constant.TRUE);

       # disable all other views
       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            me.itself["root"].getChild(me.names[i]).setValue(constant.FALSE);

            index = me.lookup[me.names[i]];
            me.dependency["views"][index].getChild("enabled").setValue(constant.FALSE);
       }
   }
}

Seats.scrollexport = func{
   me.stepView(1);
}

Seats.scrollreverseexport = func{
   me.stepView(-1);
}

Seats.stepView = func( step ) {
   var targetview = 0;
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            targetview = me.lookup[name];
            break;
        }
   }

   # ignores captain view
   if( targetview > me.CAPTINDEX ) {
       me.dependency["views"][me.CAPTINDEX].getChild("enabled").setValue(constant.FALSE);
   }

   view.stepView(step);

   # restores because of userarchive
   if( targetview > me.CAPTINDEX ) {
       me.dependency["views"][me.CAPTINDEX].getChild("enabled").setValue(constant.TRUE);
   }
}

# forwards is positiv
Seats.movelengthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = me.dependency["current-view"].getChild("goal-heading-offset-deg").getValue();

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "z-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "z-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "x-offset-m";
           sign = -1;
       }
       else {
           prop = "x-offset-m";
           sign = 1;
       }

       pos = me.dependency["current-view"].getChild(prop).getValue();
       pos = pos + sign * step;
       me.dependency["current-view"].getChild(prop).setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

# left is negativ
Seats.movewidthexport = func( step ) {
   var headdeg = 0.0;
   var prop = "";
   var sign = 0;
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       headdeg = me.dependency["current-view"].getChild("goal-heading-offset-deg").getValue();

       if( headdeg <= 45 or headdeg >= 315 ) {
           prop = "x-offset-m";
           sign = 1;
       }
       elsif( headdeg >= 135 and headdeg <= 225 ) {
           prop = "x-offset-m";
           sign = -1;
       }
       elsif( headdeg > 225 and headdeg < 315 ) {
           prop = "z-offset-m";
           sign = 1;
       }
       else {
           prop = "z-offset-m";
           sign = -1;
       }

       pos = me.dependency["current-view"].getChild(prop).getValue();
       pos = pos + sign * step;
       me.dependency["current-view"].getChild(prop).setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

# up is positiv
Seats.moveheightexport = func( step ) {
   var pos = 0.0;
   var result = constant.FALSE;

   if( me.move() ) {
       pos = me.dependency["current-view"].getChild("y-offset-m").getValue();
       pos = pos + step;
       me.dependency["current-view"].getChild("y-offset-m").setValue(pos);

       result = constant.TRUE;
   }

   return result;
}

Seats.save_lookup = func( name, index ) {
   me.names[me.nb_seats] = name;

   me.lookup[name] = index;

   me.floating[name] = constant.FALSE;

   me.nb_seats = me.nb_seats + 1;
}

# backup initial position
Seats.save_initial = func( name, view ) {
   var pos = {};
   var config = view.getNode("config");

   pos["x"] = config.getChild("x-offset-m").getValue();
   pos["y"] = config.getChild("y-offset-m").getValue();
   pos["z"] = config.getChild("z-offset-m").getValue();

   me.initial[name] = pos;

   me.floating[name] = constant.TRUE;
   me.last_recover[name] = constant.FALSE;
}

Seats.initial_position = func( name ) {
   var position = me.itself["position"].getNode(name);

   var posx = me.initial[name]["x"];
   var posy = me.initial[name]["y"];
   var posz = me.initial[name]["z"];

   me.dependency["current-view"].getChild("x-offset-m").setValue(posx);
   me.dependency["current-view"].getChild("y-offset-m").setValue(posy);
   me.dependency["current-view"].getChild("z-offset-m").setValue(posz);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);

   position.getChild("z-m").setValue(posz);
}

Seats.last_position = func( name ) {
   var position = nil;
   var posx = 0.0;
   var posy = 0.0;
   var posz = 0.0;

   # 1st restore
   if( !me.last_recover[ name ] and me.recoverfloating ) {
       position = me.itself["position"].getNode(name);

       posx = position.getChild("x-m").getValue();
       posy = position.getChild("y-m").getValue();
       posz = position.getChild("z-m").getValue();

       if( posx != me.initial[name]["x"] or
           posy != me.initial[name]["y"] or
           posz != me.initial[name]["z"] ) {

           me.dependency["current-view"].getChild("x-offset-m").setValue(posx);
           me.dependency["current-view"].getChild("y-offset-m").setValue(posy);
           me.dependency["current-view"].getChild("z-offset-m").setValue(posz);
       }

       me.last_recover[ name ] = constant.TRUE;
   }
}

Seats.recover = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.last_position( name );
            }
            break;
        }
   }
}

Seats.move_position = func( name ) {
   var posx = me.dependency["current-view"].getChild("x-offset-m").getValue();
   var posy = me.dependency["current-view"].getChild("y-offset-m").getValue();
   var posz = me.dependency["current-view"].getChild("z-offset-m").getValue();

   var position = me.itself["position"].getNode(name);

   position.getChild("x-m").setValue(posx);
   position.getChild("y-m").setValue(posy);
   position.getChild("z-m").setValue(posz);
}

Seats.move = func {
   var name = "";
   var result = constant.FALSE;

   # saves previous position
   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.move_position( name );
                result = constant.TRUE;
            }
            break;
        }
   }

   return result;
}

# restore view
Seats.restoreexport = func {
   var name = "";

   for( var i = 0; i < me.nb_seats; i=i+1 ) {
        name = me.names[i];
        if( me.itself["root"].getChild(name).getValue() ) {
            if( me.floating[name] ) {
                me.initial_position( name );
            }
            break;
        }
   }
}

# restore view pitch
Seats.restorepitchexport = func {
   var index = me.dependency["current-view"].getChild("view-number").getValue();

   if( index == me.CAPTINDEX ) {
       var headingdeg = me.dependency["views"][index].getNode("config").getChild("heading-offset-deg").getValue();
       var pitchdeg = me.dependency["views"][index].getNode("config").getChild("pitch-offset-deg").getValue();

       me.dependency["current-view"].getChild("heading-offset-deg").setValue(headingdeg);
       me.dependency["current-view"].getChild("pitch-offset-deg").setValue(pitchdeg);
   }

   # only cockpit views
   else {
       var name = "";

       for( var i = 0; i < me.nb_seats; i=i+1 ) {
            name = me.names[i];
            if( me.itself["root"].getChild(name).getValue() ) {
                var headingdeg = me.dependency["views"][index].getNode("config").getChild("heading-offset-deg").getValue();
                var pitchdeg = me.dependency["views"][index].getNode("config").getChild("pitch-offset-deg").getValue();

                me.dependency["current-view"].getChild("heading-offset-deg").setValue(headingdeg);
                me.dependency["current-view"].getChild("pitch-offset-deg").setValue(pitchdeg);
                break;
            }
        }
   }
}


# ====
# MENU
# ====

Menu = {};

Menu.new = func {
   var obj = { parents : [Menu,System],

               autopilot : nil,
               crew : nil,
               fuel : nil,
               ground : nil,
               navigation : nil,
               radios : nil,
               views : nil,
               menu : nil
         };

   obj.init();

   return obj;
};

Menu.init = func {
   me.inherit_system("/systems/crew");

   me.menu = me.dialog( "menu" );
   me.autopilot = me.dialog( "autopilot" );
   me.crew = me.dialog( "crew" );
   me.fuel = me.dialog( "fuel" );
   me.ground = me.dialog( "ground" );
   me.navigation = me.dialog( "navigation" );
   me.radios = me.dialog( "radios" );
   me.views = me.dialog( "views" );
}

Menu.dialog = func( name ) {
   var item = gui.Dialog.new(me.itself["dialogs"].getPath() ~ "/" ~ name ~ "/dialog",
                             "Aircraft/747-200/Dialogs/747-200-" ~ name ~ ".xml");

   return item;
}


# ========
# CREW BOX
# ========

Crewbox = {};

Crewbox.new = func {
   var obj = { parents : [Crewbox,System],

               MENUSEC : 3.0,

               timers : 0.0,

# left bottom, 1 line, 10 seconds.
               BOXX : 10,
               BOXY : 34,
               BOTTOMY : -768,
               LINEY : 20,

               lineindex : { "speedup" : 0, "checklist" : 1, "engineer" : 2, "copilot" : 3 },
               lasttext : [ "", "", "", "" ],
               textbox : [ nil, nil, nil, nil ],
               nblines : 4
         };

    obj.init();

    return obj;
};

Crewbox.init = func {
    me.inherit_system("/systems/crew");

    me.resize();

    setlistener(me.noinstrument["startup"].getPath(), crewboxresizecron);
    setlistener(me.noinstrument["speed-up"].getPath(), crewboxcron);
    setlistener(me.noinstrument["freeze"].getPath(), crewboxcron);
}

Crewbox.resize = func {
    var y = 0;
    var ysize = - me.noinstrument["startup"].getValue();

    if( ysize == nil ) {
        ysize = me.BOTTOMY;
    }

    # must clear the text, otherwise text remains after close
    me.clear();

    for( var i = 0; i < me.nblines; i = i+1 ) {
         # starts at 700 if height is 768
         y = ysize + me.BOXY + me.LINEY * i;

         # not really deleted
         if( me.textbox[i] != nil ) {
             me.textbox[i].close();
         }

         # CAUTION : duration is 0 (infinite), or one must wait that the text vanishes device;
         # otherwise, overwriting the text makes the view popup tip always visible !!!
         me.textbox[i] = screen.window.new( me.BOXX, y, 1, 0 );
    }

    me.crewtext();
    me.pausetext();
}

Crewbox.pausetext = func {
    var index = me.lineindex["speedup"];
    var speedup = 0.0;
    var red = constant.FALSE;
    var text = "";

    if( me.noinstrument["freeze"].getValue() ) {
        text = "pause";
    }
    else {
        speedup = me.noinstrument["speed-up"].getValue();
        if( speedup > 1 ) {
            text = sprintf( speedup, "3f.0" ) ~ "  t";
        }
        red = constant.TRUE;
    }

    me.sendpause( index, red, text );
}

crewboxresizecron = func {
    crewscreen.resize();
}

crewboxcron = func {
    crewscreen.pausetext();
}

Crewbox.minimizeexport = func {
    var value = me.itself["root"].getChild("minimized").getValue();

    me.itself["root"].getChild("minimized").setValue(!value);

    me.resettimer();
}

Crewbox.toggleexport = func {
    # 2D feedback
    if( !me.dependency["human"].getChild("serviceable").getValue() ) {
        me.itself["root"].getChild("minimized").setValue(constant.FALSE);
        me.resettimer();
    }

    # to accelerate display
    me.crewtext();
}

Crewbox.schedule = func {
    # timeout on text box
    if( me.itself["root-ctrl"].getChild("timeout").getValue() ) {
        me.timers = me.timers + me.MENUSEC;
        if( me.timers >= me.timeoutsec() ) {
            me.itself["root"].getChild("minimized").setValue(constant.TRUE);
        }
    }

    me.crewtext();
}

Crewbox.timeoutsec = func {
    var result = me.itself["root-ctrl"].getChild("timeout-s").getValue();

    if( result < me.MENUSEC ) {
        result = me.MENUSEC;
    }

    return result;
}

Crewbox.resettimer = func {
    me.timers = 0.0;

    me.crewtext();
}

Crewbox.crewtext = func {
    if( !me.itself["root"].getChild("minimized").getValue() or
        !me.itself["root-ctrl"].getChild("timeout").getValue() ) {
        me.checklisttext();
        me.copilottext();
        me.engineertext();
    }
    else {
        me.clearcrew();
    }
}

Crewbox.checklisttext = func {
    var white = constant.FALSE;
    var text = me.dependency["voice"].getChild("callout").getValue();
    var text2 = me.dependency["voice"].getChild("checklist").getValue();
    var text = "";
    var text2 = "";
    var index = me.lineindex["checklist"];

    if( text2 != "" ) {
        text = text2 ~ " " ~ text;
        white = me.dependency["voice"].getChild("real").getValue();
    }

    # real checklist is white
    me.sendtext( index, constant.TRUE, white, text );
}

Crewbox.copilottext = func {
    var green = constant.FALSE;
    var text = me.dependency["copilot"].getChild("state").getValue();
    var index = me.lineindex["copilot"];

    if( text == "" ) {
        if( me.dependency["copilot-ctrl"].getChild("activ").getValue() ) {
            text = "copilot";
        }
    }

    if( me.dependency["copilot"].getChild("activ").getValue() ) {
        green = constant.TRUE;
    }

    me.sendtext( index, green, constant.FALSE, text );
}

Crewbox.engineertext = func {
    var green = me.dependency["engineer"].getChild("activ").getValue();
    var text = me.dependency["engineer"].getChild("state").getValue();
    var index = me.lineindex["engineer"];

    if( text == "" ) {
        if( me.dependency["engineer-ctrl"].getChild("activ").getValue() ) {
            text = "engineer";
        }
    }

    me.sendtext( index, green, constant.FALSE, text );
}

Crewbox.sendtext = func( index, green, white, text ) {
    var box = me.textbox[index];

    me.lasttext[index] = text;

    # bright white
    if( white ) {
        box.write( text, 1.0, 1.0, 1.0 );
    }

    # dark green
    elsif( green ) {
        box.write( text, 0, 0.7, 0 );
    }

    # dark yellow
    else {
        box.write( text, 0.7, 0.7, 0 );
    }
}

Crewbox.sendclear = func( index, text ) {
    var box = me.textbox[index];

    me.lasttext[index] = text;

    box.write( text, 0, 0, 0 );
}

Crewbox.sendpause = func( index, red, text ) {
    var box = me.textbox[index];

    me.lasttext[index] = text;

    # bright red
    if( red ) {
        box.write( text, 1.0, 0, 0 );
    }
    # bright yellow
    else {
        box.write( text, 1.0, 1.0, 0 );
    }
}

Crewbox.clearcrew = func {
    var standbytext = "";

    for( var i = 1; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != standbytext ) {
             me.sendclear( i, standbytext );
         }
    }
}

Crewbox.clear = func {
    var standbytext = "";

    for( var i = 0; i < me.nblines; i = i+1 ) {
         if( me.lasttext[i] != standbytext ) {
             me.sendclear( i, standbytext );
         }
    }
}
