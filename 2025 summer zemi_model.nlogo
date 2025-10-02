; This model simulates the competition between traditional bank deposits (JPY) and a
; stablecoin (JPYC). The core mechanic is agent learning through experience.
; Households perform transactions and learn the benefits (low fees, speed) of JPYC,
; which dynamically updates their preference and portfolio allocation over time.
; ---

globals [
  total-jpy-in-banks
  total-jpyc-balance
]

turtles-own [
  ; Common properties
  is-household?
  is-bank?

  ; Household-specific properties
  jpy-in-bank
  jpyc-balance
  adoption-propensity
  risk-profile ; "low" or "high"
  my-bank ; The specific bank this household uses
  perceived-jpyc-utility ; Agent's learned preference for JPYC

  ; Bank-specific properties
  reserves
  initial-reserves
  initial-size
]


; ---
; SETUP PROCEDURE
; ---

to setup
  clear-all
  setup-globals
  setup-banks
  setup-households
  setup-network
  reset-ticks
end

to setup-globals
  set total-jpy-in-banks 0
  set total-jpyc-balance 0
end

to setup-banks
  create-turtles number-of-banks [
    set is-bank? true
    set is-household? false
    set shape "square"
    set color (30 + random-normal 5 1)
    set initial-size 12
    set size initial-size
    setxy random-xcor random-ycor
  ]
end

to setup-households
  let the-banks turtles with [is-bank?]
  create-turtles number-of-households [
    set is-household? true
    set is-bank? false
    set shape "person"
    set jpy-in-bank initial-deposits-per-household * random-normal 1 0.5
    set jpyc-balance 0
    setxy random-xcor random-ycor
    set my-bank one-of the-banks
    set perceived-jpyc-utility initial-jpyc-utility
  ]

  ask n-of (number-of-households / 2) turtles with [is-household?] [
    set risk-profile "high"
    set color red
    set adoption-propensity (0.5 + random-float 0.5)
  ]

  ask turtles with [is-household? and risk-profile = ""] [
    set risk-profile "low"
    set color green
    set adoption-propensity (random-float 0.5)
  ]

  ask turtles with [is-bank?] [
    set reserves sum [jpy-in-bank] of turtles with [is-household? and my-bank = myself]
    set initial-reserves reserves
  ]

  update-banks
end

to setup-network
  ask turtles with [is-household?] [
    create-links-with n-of 3 other turtles with [is-household?]
  ]
end


; ---
; GO PROCEDURE (MAIN LOOP)
; ---

to go
  if total-jpy-in-banks + total-jpyc-balance > 1000000 [stop]
  work-and-make-money
  perform-transactions

  ask n-of 10 turtles with [is-household?] [ ; A few agents re-evaluate portfolio each tick
    evaluate-portfolio
  ]

  update-banks
  update-my-plots
  tick
end

; ---
; AGENT BEHAVIORS
; ---
to work-and-make-money
  let working-households round (number-of-households * (1 - unemployment-rate))
  ask n-of working-households turtles with [is-household?] [
    ;I'm assuming companies pay salary in cash, not JPYC
    set jpy-in-bank jpy-in-bank * (1 + (yearly-salary - 1) / 365)
    ]
end

to perform-transactions
  let bank-fee-rate 0.03 ; 3% fee for bank transfers
  let jpyc-fee-rate 0.005 ; 0.5% fee for JPYC transfers

  ask n-of transactions-per-tick turtles with [is-household?] [
    let recipient one-of other turtles with [is-household?]
    let amount 10 ; A small, fixed transaction amount

    ; Agent chooses payment method based on available funds
    ifelse (jpyc-balance > amount) and (jpy-in-bank > amount) [
      ; If they have both, choose probabilistically based on perceived utility
      ifelse random-float 1.0 < (perceived-jpyc-utility / (perceived-jpyc-utility + bank-attractiveness)) [
        transact-with-jpyc amount recipient jpyc-fee-rate
      ] [
        transact-with-jpy amount recipient bank-fee-rate
      ]
    ] [
      ; This block runs if they don't have both. Now check for one or the other.
      ifelse (jpyc-balance > amount) [
        transact-with-jpyc amount recipient jpyc-fee-rate
      ] [
        if (jpy-in-bank > amount) [
          transact-with-jpy amount recipient bank-fee-rate
        ]
      ]
    ]
  ]
end

; We could let banks (and JPYC issuers) to pocket in a portion of fees they charge, to make the model more realistic.
; Right now, the only way banks and JPYC issuers can increase their funds is households moving money between banks/JPYC issuers.
to transact-with-jpy [amount recipient fee-rate]
  ; High fee, and we learn that JPYC is comparatively better
  let fee (amount * fee-rate)
  set jpy-in-bank (jpy-in-bank - amount - fee)
  ask recipient [ set jpy-in-bank (jpy-in-bank + amount) ]
  ; Negative experience with bank makes JPYC seem more attractive
  set perceived-jpyc-utility (perceived-jpyc-utility * 1.01) + random-normal 0 0.1
end

to transact-with-jpyc [amount recipient fee-rate]
  ; Low fee, instant, and we learn that JPYC is good
  let fee (amount * fee-rate)
  set jpyc-balance (jpyc-balance - amount - fee)
  ask recipient [ set jpyc-balance (jpyc-balance + amount) ]
  ; Positive experience with JPYC reinforces its utility
  set perceived-jpyc-utility (perceived-jpyc-utility * 1.01) + random-normal 0 0.1
end

to evaluate-portfolio

  let bank-health-ratio 1
  if ([initial-reserves] of my-bank > 0) [
    set bank-health-ratio ([reserves] of my-bank / [initial-reserves] of my-bank)
  ]
  let panic-modifier 1
  if bank-health-ratio < bank-confidence-threshold [
    set panic-modifier fear-factor
  ]

  let friends link-neighbors
  let peer-pressure 0
  if any? friends [
    let adopter-friends count friends with [jpyc-balance / (jpyc-balance + jpy-in-bank) > 0.3]
    set peer-pressure (adopter-friends / count friends)
  ]

  ; The agent's own learned experience is now the primary driver
  let personal-pull (perceived-jpyc-utility * adoption-propensity)
  let social-pull (peer-pressure * social-influence-factor)
  let jpyc-score (personal-pull + social-pull) * panic-modifier

  let bank-score bank-attractiveness

  let total-attraction (jpyc-score + bank-score)
  if total-attraction > 0 [
    let prob-choose-jpyc (jpyc-score / total-attraction)

    ifelse (random-float 1.0 < prob-choose-jpyc) [
      if (jpy-in-bank > 0) [
        let amount-to-move (jpy-in-bank * 0.1)
        set jpy-in-bank (jpy-in-bank - amount-to-move)
        set jpyc-balance (jpyc-balance + amount-to-move)
        ask my-bank [ set reserves (reserves - amount-to-move) ]
      ]
    ] [
      if (jpyc-balance > 0) [
        let amount-to-move (jpyc-balance * 0.1)
        set jpyc-balance (jpyc-balance - amount-to-move)
        set jpy-in-bank (jpy-in-bank + amount-to-move)
        ask my-bank [ set reserves (reserves + amount-to-move) ]
      ]
    ]
  ]
end


; ---
; HELPER & VISUALIZATION PROCEDURES
; ---

to update-banks
  set total-jpy-in-banks sum [jpy-in-bank] of turtles with [is-household?]
  set total-jpyc-balance sum [jpyc-balance] of turtles with [is-household?]

  ask turtles with [is-bank?] [
    if total-jpy-in-banks < 0 [ set total-jpy-in-banks 0 ]
    let reserve-ratio (total-jpy-in-banks / initial-reserves)
    set size (initial-size * reserve-ratio)
    ]
end

to update-my-plots
  set-current-plot "Funds Distribution"
  set-current-plot-pen "Total JPY"
  plotxy ticks total-jpy-in-banks
  set-current-plot-pen "Total JPYC"
  plotxy ticks total-jpyc-balance

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
3
11
204
44
number-of-households
number-of-households
1
500
264.0
1
1
NIL
HORIZONTAL

SLIDER
9
54
256
87
initial-deposits-per-household
initial-deposits-per-household
1
1000
100.0
1
1
NIL
HORIZONTAL

SLIDER
6
99
178
132
initial-jpyc-utility
initial-jpyc-utility
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
10
141
187
174
bank-attractiveness
bank-attractiveness
0
1
0.8
0.1
1
NIL
HORIZONTAL

SLIDER
9
187
196
220
transactions-per-tick
transactions-per-tick
1
50
10.0
1
1
NIL
HORIZONTAL

BUTTON
14
235
80
268
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
97
238
160
271
NIL
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

PLOT
705
309
1208
631
Funds Distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total JPY" 1.0 0 -16777216 true "" ""
"Total JPYC" 1.0 0 -14454117 true "" ""

SLIDER
706
20
878
53
number-of-banks
number-of-banks
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
706
79
902
112
social-influence-factor
social-influence-factor
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
706
125
931
158
bank-confidence-threshold
bank-confidence-threshold
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
707
163
879
196
fear-factor
fear-factor
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
1104
20
1282
53
Unemployment-rate
Unemployment-rate
0
0.1
0.0
0.005
1
NIL
HORIZONTAL

TEXTBOX
884
20
1034
62
todos: We could add interactions between banks later
11
0.0
1

TEXTBOX
939
126
1262
169
When bank gets confidence less than this preset value, people would panic and get much more likely (denoted by fear-factor) to use JPYC
11
0.0
1

SLIDER
1111
65
1283
98
yearly-salary
yearly-salary
1
1.05
1.05
0.0001
1
NIL
HORIZONTAL

MONITOR
1242
566
1370
611
NIL
total-jpy-in-banks
2
1
11

MONITOR
1244
515
1371
560
NIL
total-jpyc-balance
2
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
