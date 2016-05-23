
;************************************************************************************************
;********                                  Agents                                 ***************
;************************************************************************************************


;;CREATE AN AGENT CALLED "GROUP"
breed [groups group]

;; ATTRIBUTES OF PATCHES (CELLS)
patches-own
[
  p_ressource ;; current ressource level of patch
  p_max-ressource ;; maximum ressource level of patch
  ]

;; ATTRIBUTES OF GROUPS
groups-own
[
 ; conceptual attributes
 group-Energy ;; level of energy of the group
 Who-Seed-group ;; identifier of the group which gave birth to the current group

 ; visualisation variables
 age ;; number of time steps since birth of agent
 cumulated-distance ;; total distance of migration since birth
 distanceFromStart ;; distance between current position and bottom-left corner patch (starting point)
 localDensity ;; density of groups in a close circle around the current group

 ; computational attributes
 has-played? ;; used to manage playing turns between groups
 destination ;; used to manage mobility of groups
 ]

;; DEFINITION OF GLOBAL VARIABLES (IN ADDITION TO THE SLIDERS ALREADY DEFINED)
globals
[
 ;; paramaters of the model
  energy-level-of-groups-at-start ;; used twice : this is the level of energy at start and also the amount of
                                  ;; extra energy a group have to accumulate to split into two groups
 distance-exploitation ;;  radius of the ecological "niche"
 Ressource-min ;; used by function destination-minimisation-distance
 beta ;; used by destination-maximumressource

 ;; used to display level of ressources of patches (see function "colorPatches")
 max-ressource-patches
 min-ressource-patches

 ;; output indicators
 meanLocalDensity ;; average of the distribution of "localDensity" of groups
 medianDistanceFromStart ;; median of the distribution of "distanceFromStart" of groups
 globalDensity ;; density of groups in a quarter circle of radius "medianDistanceFromStart"
]


;************************************************************************************************
;********                                  Setup                                  ***************
;************************************************************************************************


to setup
  clear-all
  setup-globals
  setup-patch-ressource
  setup-groups
  RESET-TICKS
end

to setup-globals
  set distance-exploitation 2
  set energy-level-of-groups-at-start 1000
  set  Ressource-min 10
  set  beta 2
end

to setup-patch-ressource
  ;; affect ressources
 if Resource-Landscape = "Homogeneous"  [ask patches [set p_ressource 100]]
 if Resource-Landscape = "Gradient" [ask patches [set p_ressource 50 + abs (min-pycor - pycor)]]
 if Resource-Landscape = "Random" [
    ask patches [set p_ressource random 100]
    repeat 63 [diffuse p_ressource 0.50]
 ]
 if Resource-Landscape = "U-turn" [
    ask patches [
    if pxcor < 0 and pycor < 0 [set p_ressource p_ressource + 100]
    if pxcor > 0 and pycor > 0 [set p_ressource p_ressource + 200]
    if pxcor < 0 and pycor > 0 [set p_ressource p_ressource + 150]
    if pxcor > 0 and pycor < 0 [set p_ressource p_ressource + 250]
    if abs pxcor < 5 and pycor < 0 [set p_ressource 0]
    ]
 ]
 ; color patches
 ask patches
  [set p_max-ressource p_ressource]
   set  max-ressource-patches max [p_ressource] of patches
  set  min-ressource-patches min [p_ressource] of patches
  color-patches green
end


to setup-groups
  create-groups 3
  [
    ;; at patch min-pxcor min-pycor : bottom left corner
    move-to min-one-of patches with [not any? other groups in-radius distance-exploitation] [distance patch min-pxcor min-pycor]
    set group-Energy energy-level-of-groups-at-start
    set size 3
    set color 104 + who * 10
    set shape "person"
    set Who-Seed-group who
    set has-played? false
    ]
end

;************************************************************************************************
;********                       Dynamics of the model                             ***************
;************************************************************************************************

to go
  if not any? groups [stop]
  ask groups [set has-played? false]
  go-groups
  go-patches
  color-patches green
  updateReporters
  tick
end

;************************
;****patches dynamics****
;************************

to go-patches
  ask patches with [p_ressource <  p_max-ressource]
  [regrow-ressource]

end


;; LINEAR REGROW UP TO MAXIMAL LEVEL
to regrow-ressource
  set p_ressource min (list p_max-ressource (p_ressource +  Ressource-regeneration))

end


;************************
;**groups dynamics**
;************************

to go-groups

 ask groups with [has-played? = false]
 [
   die-groups
   split-groups
   migrate-groups
   update-state-of-groups
 ]
end

to update-state-of-groups
  set has-played? true
   set age age + 1
end

to migrate-groups
 let patch-around patches in-radius (distance-exploitation)
   let ressource-around sum [p_ressource] of patch-around
 ifelse  ressource-around < human-pressure
   [choose-migration-rule]
   [exploit-ressource patch-around ressource-around]
end

; ----------------------------------------
; interaction between groups and patches
; ----------------------------------------

to exploit-ressource [my-patches stock-around]

   let ressource-exploited min (list (human-pressure) stock-around) ;;on exploite "Ressource-factor" unités par habitant au maximum

   set group-Energy group-Energy + ressource-exploited

if stock-around > 0 [
   ask my-patches [
     ;each patch contributes to total amount of energy extracted relative to its level of ressources
     set p_ressource max (list 0 (p_ressource - ((p_ressource / stock-around) * ressource-exploited)))
     ]
   ]
end

; ----------------------------------------
; migration of groups
; ----------------------------------------

;; MANAGE MIGRATION OF GROUPS (USING THREE ALTERNATIVE METHODS)

to choose-migration-rule
if migration-rule = "Minimisation of distance"
  [set destination destination-closest]
  if migration-rule =  "Minimisation of distance and competition"
  [set destination destination-unoccupiedland]
  if migration-rule = "Maximisation of ressource"
  [set destination destination-maximumressource]


  ifelse is-patch? destination
  [
    let distance-destination distance destination
    set cumulated-distance cumulated-distance + distance-destination
    set group-Energy max (list 0 (group-Energy - (distance-destination ^ 2 * migration-cost)))
    move-to destination
  ][
  die
  ]
end


to-report destination-closest
  ;;
  report min-one-of other patches with [p_ressource > 10]  [distance myself]

end
to-report destination-unoccupiedland
  report min-one-of patches with [p_ressource =  p_max-ressource and not any? other groups-here]  [distance myself]
end

to-report destination-maximumressource
  report max-one-of patches in-radius (beta * distance-exploitation) with [not any? other groups-here]  [p_ressource]
end

;; if you are an expert, we suggest that you find a way for groups to find a destination
;; combining high ressources and close distance : the floor is yours !!

; ----------------------------------------
; life / death of groups
; ----------------------------------------


to die-groups
  ;; die if energy is below or equal to 0
   if group-Energy <= 0
    [die]
end

; ----------------------------------------
; toolbox : demography of groups
; ----------------------------------------

;; manage demography of groups through parthenogenesis

to split-groups
  if (energy-level-of-groups-at-start) * 2 <= group-Energy
  [
    let exceeding-wealth round ((group-Energy / 2))
    let seed-group self
      hatch 1
    [
      set group-Energy exceeding-wealth
      set size 3
      set shape "person"
      create-link-with seed-group
      set has-played? true
      set cumulated-distance 0
      pu
      ]
    set group-Energy (max (list 0 (group-Energy - exceeding-wealth)))
     choose-migration-rule
     ]

end

;************************************************************************************************
;********                         Graphic outputs                                 ***************
;************************************************************************************************

;; UPDATE COLOR OF PATCHES ACCORDING TO LEVEL OF RESSOURCES
to color-patches [seed-color]
  ifelse max-ressource-patches != min-ressource-patches
  [
  ask patches
  [
   set pcolor scale-color seed-color p_ressource max-ressource-patches min-ressource-patches
    ]
  ]
   [
  ask patches
  [
   set pcolor scale-color seed-color p_ressource  max-ressource-patches  0
    ]
  ]
end



;; UPDATE INDICATORS AT GROUP-LEVEL AND GLOBAL-LEVEL
to updateReporters
  if any? groups [
  ask groups [
  set distanceFromStart distance patch min-pxcor min-pycor
    set localDensity  100 * count groups in-radius 5  / (pi * 25)

  ]
  set medianDistanceFromStart median [distanceFromStart] of groups
  set meanLocalDensity mean [localDensity] of groups
  let temp 0
  ask patch min-pxcor min-pycor [
    set temp count groups in-radius medianDistanceFromStart
  ]
  if medianDistanceFromStart > 0 [
    set globalDensity 400 * temp / (pi * medianDistanceFromStart * medianDistanceFromStart)
  ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
231
10
725
525
60
60
4.0
1
10
1
1
1
0
0
0
1
-60
60
-60
60
1
1
1
ticks
30.0

BUTTON
26
115
115
148
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
119
115
182
148
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
17
179
215
212
Ressource-Regeneration
Ressource-Regeneration
1
25
4
1
1
NIL
HORIZONTAL

PLOT
737
37
956
202
Total number of groups
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "if any? groups [plot count groups]"

MONITOR
969
326
1061
371
Global Density
globaldensity
0
1
11

MONITOR
971
439
1063
484
Local  Density
meanlocaldensity
0
1
11

PLOT
968
37
1211
200
Median distance from starting point
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if any? groups [plot medianDistanceFromStart]"

MONITOR
969
205
1148
250
Median Distance from Start
medianDistanceFromStart
0
1
11

CHOOSER
40
33
182
78
Resource-Landscape
Resource-Landscape
"Homogeneous" "Gradient" "Random" "U-turn"
3

TEXTBOX
1158
205
1229
264
Maximum value = 85 (distance between two corners)
9
0.0
1

TEXTBOX
1071
330
1221
372
Note: \n- a value lower than 5 is low\n- a value bigger than 10 is high
9
0.0
1

SLIDER
16
271
203
304
Human-Pressure
Human-Pressure
30
150
150
10
1
NIL
HORIZONTAL

SLIDER
15
364
197
397
Migration-Cost
Migration-Cost
10
120
40
10
1
NIL
HORIZONTAL

CHOOSER
19
461
194
506
Migration-Rule
Migration-Rule
"Minimisation of distance" "Minimisation of distance and competition" "Maximisation of ressource"
1

TEXTBOX
17
217
218
262
Maximum amount of ressources a patch can accumulate at each time step
12
0.0
1

TEXTBOX
17
310
217
354
Maximum amount of ressources extracted by each group from surrounding patches in-radius 2
12
0.0
1

TEXTBOX
15
404
215
452
Amount of energy required for achieving a migration (* distance to travel)\n
12
0.0
1

TEXTBOX
20
12
215
42
Spatial distribution of ressources
12
0.0
1

TEXTBOX
781
14
931
32
SIMPLE INDICATORS
14
105.0
1

MONITOR
740
386
914
431
Average Energy of groups
mean [group-Energy] of groups
0
1
11

MONITOR
741
437
954
482
Average distance achieved by groups
sum [cumulated-distance * age] of groups with [age > 0]\n/ sum [age] of groups with [age > 0]
0
1
11

TEXTBOX
1010
15
1195
33
ADVANCED INDICATORS
14
105.0
1

PLOT
739
215
957
379
Average ressources of patches
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -10899396 true "" "plot mean [p_ressource] of patches"

TEXTBOX
970
276
1219
322
Number of groups closest to start than the median group, divided by the corresponding area.
11
0.0
1

TEXTBOX
969
258
1119
276
Global density of groups
12
105.0
1

TEXTBOX
1071
438
1248
494
Note: \n- a value lower than 5 is low\n- a value bigger than 10 is high
11
0.0
1

TEXTBOX
971
383
1121
401
Local density of groups
12
105.0
1

TEXTBOX
969
403
1253
430
Average number of groups in a small neighbourhood, divided by the corresponding area
11
0.0
1

@#$#@#$#@

## WHAT IS IT?

ColoDyn is a fairly simple model for human migration and colonisation of a continent. Starting from an empty land, it deals with interactions of groups of humans, their mobility and the relation between groups and their environment.
It is composed of two type of agents: groups and patches.

## HOW IT WORKS

The groups have three main behaviours :
* they can move accross space (on patches),
* they can extract ressources from the environment,
* they can reproduce themselves.

The patches (land) has the ability to regrow ressouces extracted by groups.

## HOW TO USE IT

See pdf document attached.

## THINGS TO NOTICE

Four initial spatial patterns of ressources are available.
Additionnaly, three migration strategies can be chosen.

## THINGS TO TRY

Try to change parameter values and observe how it changes the values of indicators.

## EXTENDING THE MODEL

Propose a new migration rule, taking into account both minimisation of distance and maximisation of ressource.

## NETLOGO FEATURES

None.

## RELATED MODELS

HUME model "Human Migration and Environment" model.


## CREDITS AND REFERENCES

Arnaud Banos, Florent Le Néchet, Hélène Mathian, Lena Sanders

http://www.transmondyn.parisgeo.cnrs.fr/
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

campsite
false
0
Polygon -7500403 true true 150 11 30 221 270 221
Polygon -16777216 true false 151 90 92 221 212 221
Line -7500403 true 150 30 150 225

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <exitCondition>medianDistanceFromStart &gt; 40
or count groups = 0</exitCondition>
    <metric>medianDistanceFromStart</metric>
    <metric>globaldensity</metric>
    <metric>meanlocaldensity</metric>
    <steppedValueSet variable="Ressource-regeneration" first="0" step="5" last="25"/>
    <steppedValueSet variable="human-pressure-on-ecology" first="30" step="30" last="150"/>
    <steppedValueSet variable="migration-cost" first="10" step="20" last="110"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
