- Festival
    - id
- Checkpoint
    - id
    - festivalId
- District
    - id
    - festivalId
- Performance
    - id
    - districtId
- Location
    - id
    - districtId
- Period
    - id
    - festivalId
    - year <!-- 一意になるのは festivalId * date だがyearでクエリすることが多い --> 
- Route
    - id
    - districtId
    - periodId
- Point
    - id
    - routeId
    - checkpointId?
    - performanceId?

pk = FESTIVAL#<festivalId>
sk = METADATA

pk = FESTIVAL#<festivalId>
sk = DISTRICT#<districtId>

pk = FESTIVAL#<festivalId>
sk = CHECKPOINT#<checkpointId>

pk = FESTIVAL#<festivalId>
sk = PERIOD#<periodId>
year = 2024

pk = DISTRICT#<districtId>
sk = PERFORMANCE#<performanceId>

pk = DISTRICT#<districtId>
sk = LOCATION#<locationId>

pk = DISTRICT#<districtId>
sk = PERIOD#<periodId>#ROUTE#
year = 2024

pk = ROUTE#<routeId>
sk = POINT#<seq>#<pointId>

