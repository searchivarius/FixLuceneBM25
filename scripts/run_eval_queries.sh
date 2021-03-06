#/bin/bash
YAHOO_ANSWERS_SOURCE="yahoo_answers"
# Set this variable to 1, if you want to compute P@1 and recall@10 instead of ERR@10 and NDCG@20
USE_OLD_STYLE_EVAL_FOR_YAHOO_ANSWERS="0"
export MAVEN_OPTS="-Xms8192m -server"
input=$1
if [ "$input" = "" ] ; then
  echo "Specify the input query file as the (1st argument)"
  exit 1
fi

if [ ! -f "$input" ] ; then
  echo "The specified input query file '$input' cannot be found!"
  exit 1
fi

source_type=$2
if [ "$source_type" = "" ] ; then
  echo "Specify query source type, e.g., $YAHOO_ANSWERS_SOURCE, trec_web"
  exit 1
fi

output=$3
if [ "$output" = "" ] ; then
  echo "Specify the top-level directory for indices of two types (3d argument)"
  exit 1
fi

max_query_qty=$4
if [ "$max_query_qty" = "" ] ; then
  echo "Specify the maximum number of queries (4th argument)"
  exit 1
fi

REP_QTY=$5
if [ "$REP_QTY" = "" ] ; then
  echo "Specify the number of times to run the Lucene pipeline (5th argument)"
  exit 1
fi

DO_EVAL=$6
if [ "$DO_EVAL" = "" ] ; then
  echo "Specify the flag that switches on/off evaluation (6th argument)"
  exit 1
fi

YAHOO_STYLE_EVAL="0"
if [ "$source_type" = "$YAHOO_ANSWERS_SOURCE" -a "$USE_OLD_STYLE_EVAL_FOR_YAHOO_ANSWERS" = "1" ] ; then
  YAHOO_STYLE_EVAL="1"
fi

if [ "$DO_EVAL" = "1" -a "$source_type" != "$YAHOO_ANSWERS_SOURCE" ] ; then
  QREL_FILE_SHORT=$7
  if [ "$QREL_FILE_SHORT" = "" ] ; then
    echo "The source type is different from $YAHOO_ANSWERS_SOURCE, hence, you have specify an external QREL file (7th argument)"
    exit 1
  fi
  if [ ! -f "$QREL_FILE_SHORT" ] ; then
    echo "Cannot find file: '$QREL_FILE_SHORT'"
    exit 1
  fi
fi

# Retrieve 100 entries
N=100

if [ "$DO_EVAL" = "1" -a "$YAHOO_STYLE_EVAL" = "1" ] ; then
  TREC_EVAL_VER="9.0.4"
  TREC_EVAL_DIR="trec_eval-${TREC_EVAL_VER}"
  if [ ! -d $TREC_EVAL_DIR -o ! -f "$TREC_EVAL_DIR/trec_eval" ] ; then
    rm -rf "$TREC_EVAL_DIR"
    echo "Downloading and building missing trec_eval" 
    wget https://github.com/usnistgov/trec_eval/archive/v${TREC_EVAL_VER}.tar.gz
    if [ "$?" != "0" ] ; then
      echo "Error downloading trec_eval"
      exit 1
    fi
    tar -zxvf v${TREC_EVAL_VER}.tar.gz
    if [ "$?" != "0" ] ; then
      echo "Error unpacking the trec_eval archive!"
      exit 1
    fi
    cd $TREC_EVAL_DIR
    if [ "$?" != "0" ] ; then
      echo "Cannot changed dir to $TREC_EVAL_VER"
      exit 1
    fi
    make
    if [ "$?" != "0" ] ; then
      echo "Error building trec_eval"
      exit 1
    fi
    cd -
    if [ "$?" != "0" ] ; then
      echo "Cannot change dir back to the starting dir"
      exit 1
    fi
    rm v${TREC_EVAL_VER}.tar.gz
  fi
fi

for type in standard fixed ; do
  INDEX_DIR="$output/$type/index"
  if [ ! -d "$INDEX_DIR" ] ; then
    echo "There is no directory $INDEX_DIR"
    exit 1
  fi

  if [ "$source_type" = "$YAHOO_ANSWERS_SOURCE" ] ; then
    QREL_FILE="$output/$type/runs/qrels.txt"
    QREL_FILE_SHORT="$output/$type/runs/qrels_short.txt"

    if [ ! -f "$QREL_FILE" ] ; then
      echo "There is no qrels.txt file in the directory $INDEX_DIR did the indexing procedure finish properly?"
      exit 1
    fi
  fi


  flag=""
  if [ "$type" = "standard" ] ; then
    echo "Querying the index using the standard Lucene similarity"
  else
    echo "Querying the index using the fixed Lucene similarity"
    flag=" -bm25fixed "
  fi

  mkdir -p "$output/$type/runs"
  OUT_FILE="$output/$type/runs/trec_run"
  LOG_FILE="$output/$type/query.log"
  echo > $LOG_FILE
  if [ "$?" != "0" ] ; then
    echo "Error writing to $LOG_FILE"
    exit 1
  fi
  if [ ! -f "$OUT_FILE" ] ; then
    echo "Re-running Lucene"
    for ((i=0;i<$REP_QTY;i++)) ; do
      echo "Query iteration $(($i+1))"
      scripts/lucene_query.sh -s data/stopwords.txt -i "$input" -source_type "$source_type" -d "$INDEX_DIR" -prob 1.0 -n $N -max_query_qty "$max_query_qty" -o "$OUT_FILE" $flag 2>&1 >> ${LOG_FILE}

      if [ "$?" != "0" ] ; then
        echo "lucene_query.sh failed!"
        exit 1
      fi
    done
  else
    echo "Re-using existing run: $OUT_FILE"
  fi
  if [ "$DO_EVAL" = "1" ] ; then
    echo "Let's evaluate output quality"
    EVAL_REPORT_PREFIX="$output/$type/runs/eval"
    if [ "$source_type" = "$YAHOO_ANSWERS_SOURCE" ] ; then
      # For Yahoo Answers's type of source queries
      # the qrel file will be huge, so we need to truncate it
      # to make evaluation feasible
      head -$max_query_qty $QREL_FILE > $QREL_FILE_SHORT
      if [ "$?" != "0" ] ; then
        echo "Failed to create $QREL_FILE_SHORT"
        exit 1
      fi
    fi
    if [ "$YAHOO_STYLE_EVAL" = "1" ] ; then
      scripts/eval_output_trec_eval.py "$TREC_EVAL_DIR/trec_eval" "$QREL_FILE_SHORT" "$OUT_FILE" "$EVAL_REPORT_PREFIX"
      if [ "$?" != "0" ] ; then
        echo "scripts/eval_output_trec_eval.py failed!"
        exit 1
      fi
    else
      scripts/eval_output_gdeval.py "scripts/gdeval.pl" "$QREL_FILE_SHORT" "$OUT_FILE" "$EVAL_REPORT_PREFIX"
      if [ "$?" != "0" ] ; then
        echo "scripts/eval_output_gdeval.py failed!"
        exit 1
      fi
    fi
  fi
  
done
if [ "$DO_EVAL" = "1" ] ; then
  echo "Let's now compute p-values and ratios"
  if [ "$YAHOO_STYLE_EVAL" = "1" ] ; then
    metrics=(recall "recall@10" "P@1" map)
  else
    metrics=("ndcg@20" "err@20")
  fi
  for metr in ${metrics[*]} ; do
    echo "============================================="
    echo " Evaluation metric: $metr "
    echo "============================================="
    EVAL_REPORT_STANDARD="$output/standard/runs/eval.$metr"
    EVAL_REPORT_FIXED="$output/fixed/runs/eval.$metr"
    scripts/p-val.R "$EVAL_REPORT_FIXED" "$EVAL_REPORT_STANDARD"
  done
fi


