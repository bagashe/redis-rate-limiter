A Lua script extension for Redis that provides **smooth**, **configurable**, **space-efficient** & **blazing fast** rate limiting. 
                                                                                                     
### Configuration  
##### Example
```
key = "api-access"                                                                                 
value = {"1000", "3600", "300"}                                                                    
```
Each `actor` will be rate limited to `1000` `api-access` events per `3600 seconds`. Once the limit   
is reached, the `actor` will be locked out for `300 seconds`. Note that the rate limit applies over  
a rolling window.                                                                                    
                                                                                                     
### Features                                                                                                     
This rate-limiting solution -                                                                        
1. Does not use buckets & does not enumerate events. So it is space-efficient. It stores everything  
in a three-tuple for each `actor`,`event` pair.                                                      
2. Uses a simple linear decay function to compute available quota. So it is blazing fast.            
3. Can be easily configured to rate limit over a few seconds or a few hours or a few days.           
                                                                                                     
### Usage                                                                                               
```
1. To check available quota without registering an event.
evalsha <SHA> 2 api-access <actor-id> <current-timestamp-seconds-since-epoch>                      

2. To check available quota while registering an event.
evalsha <SHA> 2 api-access <actor-id> <current-timestamp-seconds-since-epoch> 1                      
```
Included `test.sh` provides an example of how to configure an event type. It also shows the rate limiting in action.



#### The script returns available quota as a fraction. So when the rate limit is reached, it returns "0".                                                                                         
                                                                                                     
### Performance                                                                                         
Processor: Intel® Core™ i7-8550U CPU @ 1.80GHz × 8                                     
Using: `benchmark.sh`            
Results: **142836.73 requests per second** with **99%** of them being served in under **0.6 ms**                     
_Note that client and server were running on the same machine. Even so, it proves that performance of this Lua script should not be an issue._                                               
