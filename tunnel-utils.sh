#!/bin/bash
declare -i TIMEOUT=600
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo 'Choose Env: '
options_env=("dev (main)" "int" "scale" "prod")
options_utils=("starburst" "neo4j" "neo4j-rbac" "kafka" "kafka-ui")

echo -e "Current context: ${GREEN}$(kubectl config current-context)${NC}"
if [[ "$1" == "" ]] && [[ "$2" == "" ]]; then
  select opt in "${options_env[@]}"
  do
    case $opt in
      "dev (main)")
        ENV="main"
        break;;    
      "int")
        ENV="int"
        break;;
      "scale")
        ENV="scale"
        break;;
      "prod")
        ENV="prod"
        break;;
      * ) echo "Please select an option.";
    esac
  done

if [[ "$ENV" == "main" ]]; then
  options_utils=("starburst" "kafka-ui")
fi

  select opt in "${options_utils[@]}"
  do
    case $opt in
      "starburst")
        UTIL="starburst"
        PORT=8080
        break;;
      "neo4j")
        UTIL="neo4j"
        PORT=7687
        break;;
      "neo4j-rbac")
        UTIL="neo4j-rbac"
        PORT=7687
        break;;
      "kafka")
        UTIL="kafka"
        PORT=9094
        break;;
      "kafka-ui")
        UTIL="kowl"
        PORT=8080
        break;;
      * ) echo "Please select an option.";
    esac
  done
else
  ENV=$1
  UTIL=$2
  if [[ "$UTIL" == "starburst" ]]; then
    PORT=8080
  elif [[ "$UTIL" == "neo4j" ]]; then
    PORT=7687
  elif [[ "$UTIL" == "neo4j-rbac" ]]; then
    PORT=7687  
  elif [[ "$UTIL" == "kafka" ]]; then
    PORT=9094
  elif [[ "$UTIL" == "kafka-ui" ]]; then
    UTIL="kowl"
    PORT=8080
  else
    echo "wrong args"
    exit 1
  fi
fi

kubectl --namespace $ENV run \
 $UTIL-tunnel --image=alpine/socat \
 --expose=true --port=$PORT \
 tcp-listen:$PORT,fork,reuseaddr tcp-connect:$UTIL:$PORT,reuseaddr > /dev/null 2>&1

if [ "$UTIL" == "neo4j" ] || [ "$UTIL" == "neo4j-rbac" ]; then
  kubectl --namespace $ENV run \
  $UTIL-tunnel-ui --image=alpine/socat \
  --expose=true --port=7474 \
  tcp-listen:7474,fork,reuseaddr tcp-connect:$UTIL:7474,reuseaddr > /dev/null 2>&1
fi

echo -e "${RED}port-forwarding for 10min!${NC}"
kubectl -n $ENV wait --for=condition=ready --timeout=180s pod/$UTIL-tunnel || exit 1

if [ "$UTIL" == "neo4j" ] || [ "$UTIL" == "neo4j-rbac" ]; then
  ./scripts/tunnel/timeout.sh kubectl port-forward -n $ENV $UTIL-tunnel $PORT &
  echo -e "${GREEN}Running port-forward for neo4j, ui: localhost:7474${NC}"
  ./scripts/tunnel/timeout.sh kubectl port-forward -n $ENV $UTIL-tunnel-ui 7474
else
  echo -e "${GREEN}Running port-forward for $UTIL on port: $PORT${NC}"
  ./scripts/tunnel/timeout.sh kubectl port-forward -n $ENV $UTIL-tunnel $PORT
fi
