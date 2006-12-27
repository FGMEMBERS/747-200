747-200  real data
==================
Weight limit (A) :
    maximum (takeoff)     : 833000 lb.
    landing (recommended) : 630000 lb.

VMO/MMO : 375/0.92 (A).
VNE/MNE : 445/0.95 (B).

Ceiling : 45100 ft (C).


747-200 ops
===========
- takeoff : - rotation 180 kt (full load), 170 kt (landing load), flaps 20 (D1).
            - trim before engaging autopilot.
- climb   : flaps retraction scheduled with autothrottle (D2).
- cruise  : 0.84 mach.
- descent : start at 225 NM.
- approach: 160 kt (landing load), 150 kt (empty tank), flaps 20.
- final   : - 160 kt (landing load), 150 kt (empty tank), flaps 30.
            - arm spoilers.
- landing : - 154 kt (landing load), 140 kt (empty tank) (D1).
            - touch down below 400 ft/min.


Installation
============
If your preferences.xml doesn't have 6 views, update Nasal/747-200-views.xml.

Fuel load
---------
- default is maximum landing weight, 630000 lb.
- for alternate load, press "ctrl-M f" (saved on exit by userarchive).

Known compatibility
-------------------
- 0.9.11 : nasal loads menus, and Systems/747-200-instrumentation.xml.
- 0.9.10 : JSBSim 2.0 FDM.
- 0.9.9  : object nasal.


Keyboard
========
- "ctrl-M" : "M"enu.
- "q"      : quit speed up.

Views
-----
- "ctrl-M c" : debug views.

Same behaviour
--------------
- "ctrl-R" : radio frequencies.
- "s" swaps between Captain and Center 2D panels.
 
Improved behaviour
------------------
- "a / A"  : speeds up BOTH speed and time. Until X 15.
             Automatically resets to 1, when above 2000 ft/min.

Alternate behaviour
-------------------
- "ctrl-T" : toggle altitude hold.
- "up / down"  : move floating view in length.
- "home / end" : move floating view in length (fast).
- "left / right" : move floating view in width.
- "page up / page down" : move floating view in height.

Disabled
--------
- "ctrl-P".
- "ctrl-W".


Mouse
=====

ADF
---
To update the frequency of ADF 2 :
- press "swap" on the overhead.
- press "ctrl-R" to call the radio menu. 


Consumption
===========
Cruise Mach 0.84 for 1 engine :
- full load, 900 gallons/h at 30000 ft.
- empty fuel, 1050 gallons/h at 38000 ft.

All with lateral wind.

Example
-------
KMSP - RJAA (E), 5300 NM :
- load --flight-plan from Doc.
- at 12h45 zulu (morning), takeoff at full load (55212 US gal).
- warm, with light adverse alofts.
- cruise starts at 30000 ft, +2000 ft every 2h30, until 38000 ft.
- after 11h45, lands in the morning with 8200 gallons (1000 gallons/h); or 2h / 920 NM.

Typical city pair (F) KJFK - RJAA (6000 NM) is not possible at full load (A).


JSBSim
======
- geometry is real data.
- center of gravity inside corridor.
- extended range 7500 NM (6200 NM at full load), without wind (A).


TO DO
=====
- 3D cockpit.

TO DO JSBSim
------------
- body gear steering is reversed (with hysteresis).


Known problems
==============
- taxi turns : body gear steering (without, turn radius is too large) should be reversed.

Known problems autopilot
------------------------
- close waypoint may not pop for the next one, to avoid a strong bank.
- heading hold is a little slow to converge.
- beyond 15 NM, nav hold makes wide rolls.

Known problems autoland
-----------------------
- nav must be accurate until 0 ft AGL : KSFO 28R, RJAA 34L are correct;
  but EGLL 27R, KJFK 22L are wrong : to land at these airports,
  set /controls/autoflight/real-nav to false, by "ctrl-M c".
- glide slope must be accurate until 200 ft AGL : real should be 100 ft,
  but nose tends to dive to catch the slope (simplistic autopilot or wrong glide slope ?).


References
==========
(A) http://www.boeing.com/ :
    (747 airplane characteristics, D6-58236 - May 1984).

(B) http://www.bh.com/companions/034074152X/appendices/data-a/table-3/table.htm :

(C) http://www.airweb.faa.gov/Regulatory_and_Guidance_Library/rgMakeModel.nsf/MainFrame?OpenFrameSet :
    (FAA certificate, a20we - 23 December 1970, 747-200B).

(D1) http://www.airliners.net/discussions/tech_ops/read.main/52218/6/#ID52218 :
    V2 190 kt (max takeoff load), climbs with no flaps at V2 + 100 kt, VREF 154 kt (max landing load).

(D2) http://www.airliners.net/discussions/tech_ops/read.main/72686/6/#ID72686 :
    retract V2 + 80, for maneuver V2 + 100; extend Vref + 80.

(E) http://www.airlineroutemaps.com/USA/Northwest_Airlines.shtml :
    KDTW - RJAA is 5800 NM.

(F) http://www.boeing.com/ :
    747 Classics.


16 December 2006.
