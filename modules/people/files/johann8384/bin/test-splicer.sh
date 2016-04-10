#!/bin/bash -x

# time curl -s -X POST dwh-edge001.atl1.turn.com:4245/api/query -d '{"start":1444824698791,"end":1444846284657,"queries":[{"metric":"turn.bid.rtb.bidrequest.all","aggregator":"sum","rate":true,"rateOptions":{"counter":false},"downsample":"10m-avg"}]}' | js

# ARR_METRICS=( "turn.bid.rtb.bidrequest.all" "turn.KeyValueStoreClient.requests.failures" "turn.KeyValueStoreClient.requests.count" )
ARR_METRICS=( "turn.bid.rtb.bidrequest.all" "turn.KeyValueStoreClient.requests.failures" "turn.KeyValueStoreClient.requests.count" "turn.impression.impressions.call" "turn.QC.AdsReturned.Aggregate" "turn.QC.NoAdsReturned.Aggregate")

SPLICER_HOST=$1

INTERVAL=96
CURRENT_TIME="$(date +%s)000"
START_TIME=$(echo "$CURRENT_TIME - $INTERVAL * 3600 * 1000" | bc )

echo "Current Time  " $CURRENT_TIME
echo "Start   Time  " $START_TIME

for METRIC in "${ARR_METRICS[@]}"
do
        echo ${METRIC}
        time curl -s -X POST ${SPLICER_HOST}/api/query -d "{\"start\":${START_TIME},\"end\":${CURRENT_TIME},\"queries\":[{\"metric\":\"${METRIC}\",\"aggregator\":\"sum\",\"rate\":true,\"rateOptions\":{\"counter\":false},\"downsample\":\"10m-avg\"}]}" > /dev/null &
done

ARR_DOMS=( "sjc2" "atl1" "ams1" "hkg1" )

for DOMAIN in "${ARR_DOMS[@]}"
do
        echo "Querying for domain" $DOMAIN
        time curl -X POST ${SPLICER_HOST}/api/query -d "{\"start\":${START_TIME},\"end\":${CURRENT_TIME},\"queries\":[{\"metric\":\"turn.bid.rtb.bidrequest.all\",\"tags\":{\"domain\":\"${DOMAIN}\"},\"aggregator\":\"sum\",\"rate\":true,\"rateOptions\":{\"counter\":false},\"downsample\":\"10m-avg\"}]}" &
        time curl -X POST ${SPLICER_HOST}/api/query -d "{\"start\":${START_TIME},\"end\":${CURRENT_TIME},\"queries\":[{\"metric\":\"turn.impression.impressions.call\",\"tags\":{\"domain\":\"${DOMAIN}\"},\"aggregator\":\"sum\",\"rate\":true,\"rateOptions\":{\"counter\":false},\"downsample\":\"10m-avg\"}]}" &
        time curl -X POST ${SPLICER_HOST}/api/query -d "{\"start\":${START_TIME},\"end\":${CURRENT_TIME},\"queries\":[{\"metric\":\"turn.QC.AdsReturned.Aggregate\",\"tags\":{\"domain\":\"${DOMAIN}\"},\"aggregator\":\"sum\",\"rate\":true,\"rateOptions\":{\"counter\":false},\"downsample\":\"10m-avg\"}]}" &
        time curl -X POST ${SPLICER_HOST}/api/query -d "{\"start\":${START_TIME},\"end\":${CURRENT_TIME},\"queries\":[{\"metric\":\"turn.QC.NoAdsReturned.Aggregate\",\"tags\":{\"domain\":\"${DOMAIN}\"},\"aggregator\":\"sum\",\"rate\":true,\"rateOptions\":{\"counter\":false},\"downsample\":\"10m-avg\"}]}" &
done

wait

CURRENT_TIME="$(date +%s)000"
END_TIME=$(echo "$CURRENT_TIME - $INTERVAL * 3600 * 1000" | bc )

echo "Start   Time  " $START_TIME
echo "End   Time  " $END_TIME
