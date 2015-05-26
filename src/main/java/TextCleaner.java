import java.util.Properties;

import edu.stanford.nlp.ling.CoreAnnotations;
import edu.stanford.nlp.ling.CoreAnnotations.LemmaAnnotation;
import edu.stanford.nlp.ling.CoreAnnotations.TextAnnotation;
import edu.stanford.nlp.ling.CoreLabel;
import edu.stanford.nlp.pipeline.Annotation;
import edu.stanford.nlp.pipeline.StanfordCoreNLP;

/*
 *  Copyright 2015 Carnegie Mellon University
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

/**
 * 
 * A simple class to extract a "clean" sequence of tokens from a potentially
 * messy text.
 * 
 * @author Leonid Boytsov, modeled after http://nlp.stanford.edu/software/corenlp.shtml
 *
 */
public class TextCleaner {
  public TextCleaner() {
    initTextCleaner(UtilConst.USE_STANFORD, UtilConst.DO_LEMMATIZE);
  }
  private void initTextCleaner(boolean useStanford, boolean lemmatize) {
    mUseStanford = useStanford;
    mLemmatize = lemmatize;
    Properties props = new Properties();
    if (lemmatize)
      props.setProperty("annotators", "tokenize, ssplit, pos, lemma");
    else
      props.setProperty("annotators", "tokenize");
    
    mPipeline = new StanfordCoreNLP(props);  
  }
  
  public String cleanUp(String text) {
    if (mUseStanford) {
      Annotation doc = new Annotation(text);
      mPipeline.annotate(doc);
      
      StringBuffer sb = new StringBuffer();
      
      for (CoreLabel token: doc.get(CoreAnnotations.TokensAnnotation.class)) {
        String word = mLemmatize ?
                      token.get(LemmaAnnotation.class) :
                      token.get(TextAnnotation.class);
        sb.append(word);
        sb.append(' ');
      }
      return sb.toString();
    } else return text;
  }
  
  /**
   * Removes characters that get a special treatment by the Lucene query parser.
   * 
   */
  public static String luceneSafeCleanUp(String s) {
    return s.replaceAll("[-&|!(){}\\[\\]^\"~*?:\\\\/]", " ");
  }
  
  private StanfordCoreNLP   mPipeline = null;
  private boolean           mLemmatize = false;
  private boolean           mUseStanford = false;
}