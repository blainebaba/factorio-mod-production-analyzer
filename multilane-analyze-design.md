## Problem

The limitation of current analyze is that, it assumes producers are from upstream and consumers are from downstream (relative to the analyze start point), which is not always true. 

The multilane analyze tries to solve this problem by considering complex producers consumers connections. For example:

```
           | 2
           V
1          |    4
-->-- -->-- -->--
     |
     V
     | 3
```

Here 1,2 are producers and 3,4 are consumers. There is no way to init single analysis that can cover all 4 places. But if init two analysis in-front of 3 and 4 will cause 1 get computed twice hence the result is incorrect.

The problem is further complicated if we consider the splitter priority. If prioritizes resources from 1 to 4, that could cause 3 starves and 2 get clogged, which doesn't fully utilize capacity.

## Multi-lane detection
Detects all lanes by scan back and forth until converge. Trim branches that are for other resources. Because of the complexity, each time only one resources can be analyzed.

All belts should be separated into sections, separated by intersections/splitters. productions and consumptions are computed in each section, then extra productions are passed to next sections. 

## Priority analyze
Given the design in previous section, priority can be considered when extra productions are passed to next sections. Prioritized lane can be saturated and then more resources are pushed to de-prioritized lane, that needs to be considered as well. 

## Nuances
* What about machines connects to splitter, which section should it belongs?
* What about machines connects to two sections?
* What about resources from/to chests/trains?