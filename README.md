# Production Analyzer

Analyze production and consumption rate of resources transported by a given belt. 

![monitor demo](./thumbnail.png)

### Features
* Starts from a belt, finds upstream and downstream machines and calculates production/consumption. Productions are calculated from upstream machines and consumptions are calculated from downstream machines, which means if a machine at upstream consumes resources from this belt line, its consumption will be be calculated. Find right place to init the analysis will decide if the calculation is correct. Press `ctrl + S` to analyze and print result in console. Press `ctrl + A` to attach monitor to belt that will constantly analyze (only visible in alt mode). Press `ctrl + A` again on the same belt to remove monitor. 
* Works for assembling machines, furnaces, mining drills and boiler. 
* To accurately refect production/consumption rate, downstream machines in full output state are excluded. Similarly, upstream machines in missing input state are excluded. 
* Speed modules and productivity modules are considered. Also beacon.

### Limitations
* No support for fuilds yet.
* No support for ghost entities yet.