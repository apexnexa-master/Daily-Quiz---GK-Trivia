import 'package:flutter/material.dart';

class GameIntroData {
  final String id;
  final String title;
  final String titleBn;
  final String titleHi;
  final String tagline;
  final String taglineBn;
  final String taglineHi;
  final IconData icon;
  final Color accentColor;
  final Color? secondaryColor;
  final String brainBenefit;
  final String brainBenefitBn;
  final String brainBenefitHi;
  final List<String> rules;
  final List<String> rulesBn;
  final List<String> rulesHi;
  final String targetRoute;
  final Map<String, dynamic>? targetArgs;
  final bool showOrbitingOperators;
  final bool showOrbitingDots;

  const GameIntroData({
    required this.id,
    required this.title,
    required this.titleBn,
    required this.titleHi,
    required this.tagline,
    required this.taglineBn,
    required this.taglineHi,
    required this.icon,
    required this.accentColor,
    this.secondaryColor,
    required this.brainBenefit,
    required this.brainBenefitBn,
    required this.brainBenefitHi,
    required this.rules,
    required this.rulesBn,
    required this.rulesHi,
    required this.targetRoute,
    this.targetArgs,
    this.showOrbitingOperators = false,
    this.showOrbitingDots = false,
  });

  static const Map<String, GameIntroData> games = {
    'arrow-puzzle': GameIntroData(
      id: 'arrow-puzzle',
      title: 'ARROW PUZZLE',
      titleBn: 'এরো পাজল',
      titleHi: 'एरो पज़ल',
      tagline: 'Navigate. Think. Solve.',
      taglineBn: 'নেভিগেট করুন। ভাবুন। সমাধান করুন।',
      taglineHi: 'नेविगेट करें। सोचें। हल करें।',
      icon: Icons.route_rounded,
      accentColor: Color(0xFF00F1FE),
      secondaryColor: Color(0xFF0091FF),
      brainBenefit:
          'Sharpens logical reasoning and spatial awareness. Each puzzle requires you to plan multi-step paths, strengthening your prefrontal cortex — the brain region responsible for strategic thinking and problem solving.',
      brainBenefitBn:
          'যুক্তিবাদী চিন্তা ও স্থানিক সচেতনতা বাড়ায়। প্রতিটি পাজলে বহু-ধাপের পথ পরিকল্পনা করতে হয়, যা প্রিফ্রন্টাল কর্টেক্সকে শক্তিশালী করে।',
      brainBenefitHi:
          'तर्कशक्ति और स्थानिक जागरूकता बढ़ाता है। हर पज़ल में बहु-चरणीय मार्ग की योजना बनानी होती है, जो प्रीफ्रंटल कॉर्टेक्स को मजबूत करता है।',
      rules: [
        'Swipe or tap arrows to rotate grid cells',
        'Connect the start point to the end point',
        'Complete the path within the move limit',
        'Each level gets progressively harder',
        'Use hints if you get stuck',
      ],
      rulesBn: [
        'সোয়াইপ বা ট্যাপ করে গ্রিড ঘুরান',
        'শুরু থেকে শেষ পর্যন্ত পথ সংযোগ করুন',
        'নির্ধারিত মুভে সমাধান করুন',
        'প্রতিটি লেভেল ক্রমশ কঠিন হয়',
        'আটকে গেলে হিন্ট ব্যবহার করুন',
      ],
      rulesHi: [
        'स्वाइप या टैप करके ग्रिड घुमाएँ',
        'शुरुआत से अंत तक पथ जोड़ें',
        'दिए गए मूव्स में हल करें',
        'हर लेवल कठिन होता जाता है',
        'फँस जाएँ तो हिंट का उपयोग करें',
      ],
      targetRoute: '/arrow-puzzle',
    ),
    'stroop-rush': GameIntroData(
      id: 'stroop-rush',
      title: 'STROOP RUSH',
      titleBn: 'স্ট্রুপ রাশ',
      titleHi: 'स्ट्रूप रश',
      tagline: 'Colors speak. Listen carefully.',
      taglineBn: 'রং কথা বলে। মনোযোগ দিন।',
      taglineHi: 'रंग बोलते हैं। ध्यान से सुनें।',
      icon: Icons.palette_rounded,
      accentColor: Color(0xFFECB2FF),
      secondaryColor: Color(0xFFCF5CFF),
      brainBenefit:
          'Trains selective attention and cognitive flexibility — the ability to inhibit automatic responses. This Stroop effect exercise strengthens your anterior cingulate cortex, improving focus and reducing mental interference.',
      brainBenefitBn:
          'নির্বাচিত মনোযোগ ও জ্ঞানীয় নমনীয়তা প্রশিক্ষণ দেয়। এই স্ট্রুপ ইফেক্ট ব্যায়াম অ্যান্টেরিয়র সিঙ্গুলেট কর্টেক্সকে শক্তিশালী করে।',
      brainBenefitHi:
          'चयनात्मक ध्यान और संज्ञानात्मक लचीलापन प्रशिक्षित करता है। यह स्ट्रूप प्रभाव व्यायाम एंटेरियर सिंगुलेट कॉर्टेक्स को मजबूत करता है।',
      rules: [
        'A color word appears on screen',
        'Tap the button matching the INK color, not the word',
        'Speed increases as you score higher',
        '3 mistakes and the game ends',
        'Streaks earn bonus points',
      ],
      rulesBn: [
        'একটি রঙের শব্দ দেখানো হয়',
        'শব্দ নয়, কালির রঙের সাথে মিলিয়ে ট্যাপ করুন',
        'স্কোর বাড়লে গতি বাড়ে',
        '৩টি ভুলে খেলা শেষ',
        'স্ট্রিক বোনাস পয়েন্ট দেয়',
      ],
      rulesHi: [
        'एक रंग का शब्द स्क्रीन पर दिखता है',
        'शब्द नहीं, स्याही के रंग से मिलाकर टैप करें',
        'स्कोर बढ़ने पर गति बढ़ती है',
        '3 गलतियों में खेल खत्म',
        'स्ट्रीक से बोनस अंक मिलते हैं',
      ],
      targetRoute: '/stroop-rush',
    ),
    'synapse-recall': GameIntroData(
      id: 'synapse-recall',
      title: 'SYNAPSE RECALL',
      titleBn: 'সিন্যাপস রিকল',
      titleHi: 'सिनैप्स रीकॉल',
      tagline: 'Remember. Rebuild. Repeat.',
      taglineBn: 'মনে রাখুন। পুনর্গঠন করুন। পুনরাবৃত্তি করুন।',
      taglineHi: 'याद रखें। दोबारा बनाएँ। दोहराएँ।',
      icon: Icons.psychology_rounded,
      accentColor: Color(0xFFB388FF),
      secondaryColor: Color(0xFF7C4DFF),
      brainBenefit:
          'Directly trains working memory and visual-spatial recall. The growing sequence challenges your hippocampus to encode and retrieve patterns, boosting short-term memory capacity and neural connection speed.',
      brainBenefitBn:
          'ওয়ার্কিং মেমরি ও ভিজ্যুয়াল-স্প্যাশাল রিকল প্রশিক্ষণ দেয়। বর্ধমান সিকোয়েন্স হিপোক্যাম্পাসকে চ্যালেঞ্জ করে।',
      brainBenefitHi:
          'वर्किंग मेमरी और विजुअल-स्पेशियल रीकॉल का प्रशिक्षण करता है। बढ़ता क्रम हिप्पोकैम्पस को चुनौती देता है।',
      rules: [
        'Watch the pattern of lit nodes',
        'Recreate the sequence from memory',
        'Each round adds one more node',
        'Make a mistake and the round resets',
        'How far can your memory go?',
      ],
      rulesBn: [
        'আলোকিত নোডের প্যাটার্ন দেখুন',
        'স্মৃতি থেকে সিকোয়েন্স তৈরি করুন',
        'প্রতিটি রাউন্ডে একটি নোড যোগ হয়',
        'ভুল করলে রাউন্ড রিসেট হয়',
        'আপনার স্মৃতি কতদূর যায়?',
      ],
      rulesHi: [
        'जलते नोड्स का पैटर्न देखें',
        'याद से क्रम दोबारा बनाएँ',
        'हर राउंड में एक नोड जुड़ता है',
        'गलती पर राउंड रीसेट',
        'आपकी याददाश्त कितनी लंबी है?',
      ],
      targetRoute: '/synapse-recall',
    ),
    'math-sprint': GameIntroData(
      id: 'math-sprint',
      title: 'MATH SPRINT',
      titleBn: 'ম্যাথ স্প্রিন্ট',
      titleHi: 'मैथ स्प्रिंट',
      tagline: 'Crunch numbers. Beat the clock.',
      taglineBn: 'দ্রুত গণিত সমাধান করুন।',
      taglineHi: 'तेज़ गति से गणित हल करें।',
      icon: Icons.speed_rounded,
      accentColor: Color(0xFFD4FF50),
      secondaryColor: Color(0xFF00E7A0),
      brainBenefit:
          'Boosts processing speed and mental arithmetic. Under time pressure, your brain rapidly switches between calculation strategies, strengthening neural pathways for quick numerical reasoning.',
      brainBenefitBn:
          'প্রক্রিয়াকরণ গতি ও মানসিক গণনা বাড়ায়। সময় চাপে মস্তিষ্ক দ্রুত গণনা কৌশল পরিবর্তন করে।',
      brainBenefitHi:
          'प्रोसेसिंग स्पीड और मानसिक गणना बढ़ाता है। समय दबाव में मस्तिष्क तेज़ी से गणना रणनीतियाँ बदलता है।',
      rules: [
        '60 seconds on the clock',
        'Solve as many problems as you can',
        'Every 5 correct answers levels you up',
        'Combo streaks multiply your points',
        '3 mistakes and the game ends',
      ],
      rulesBn: [
        '৬০ সেকেন্ড সময়',
        'যতগুলো সম্ভব সমস্যা সমাধান করুন',
        'প্রতি ৫টি সঠিক উত্তরে লেভেল বাড়ে',
        'কম্বো স্ট্রিক পয়েন্ট গুণ করে',
        '৩টি ভুলে খেলা শেষ',
      ],
      rulesHi: [
        '60 सेकंड का समय',
        'जितना हो सके समस्याएँ हल करें',
        'हर 5 सही उत्तर पर स्तर बढ़ता है',
        'कॉम्बो स्ट्रीक अंक कई गुना बढ़ाते हैं',
        '3 गलतियों में खेल खत्म',
      ],
      targetRoute: '/math-sprint',
      showOrbitingOperators: true,
    ),
    'gk-quiz': GameIntroData(
      id: 'gk-quiz',
      title: 'GK QUIZ',
      titleBn: 'জিকিউ কুইজ',
      titleHi: 'जीक्यू क्विज़',
      tagline: 'Test your knowledge. Level up your mind.',
      taglineBn: 'আপনার জ্ঞান পরীক্ষা করুন।',
      taglineHi: 'अपने ज्ञान की परीक्षा लें।',
      icon: Icons.quiz_rounded,
      accentColor: Color(0xFFD4FF50),
      secondaryColor: Color(0xFF8BC34A),
      brainBenefit:
          'Expands general knowledge and strengthens long-term memory retrieval. Answering diverse questions activates multiple brain regions simultaneously — temporal lobe for facts, frontal lobe for reasoning.',
      brainBenefitBn:
          'সাধারণ জ্ঞান বাড়ায় এবং দীর্ঘমেয়াদী স্মৃতি শক্তিশালী করে। বিভিন্ন ধরনের প্রশ্নের উত্তর দেওয়া মস্তিষ্কের একাধিক অংশকে একই সাথে সক্রিয় করে।',
      brainBenefitHi:
          'सामान्य ज्ञान बढ़ाता है और दीर्घकालिक स्मृति को मजबूत करता है। विविध प्रश्नों के उत्तर देने से मस्तिष्क के कई क्षेत्र एक साथ सक्रिय होते हैं।',
      rules: [
        'Answer general knowledge questions',
        'Choose from 4 options per question',
        'Faster answers earn bonus points',
        'Difficulty adapts to your level',
        'Track your progress across categories',
      ],
      rulesBn: [
        'সাধারণ জ্ঞানের প্রশ্নের উত্তর দিন',
        'প্রতিটি প্রশ্নে ৪টি অপশন',
        'দ্রুত উত্তরে বোনাস পয়েন্ট',
        'কঠিনতা আপনার স্তর অনুযায়ী মানানসই',
        'বিভিন্ন বিষয়ে অগ্রগতি ট্র্যাক করুন',
      ],
      rulesHi: [
        'सामान्य ज्ञान के प्रश्नों के उत्तर दें',
        'हर प्रश्न में 4 विकल्प',
        'तेज़ उत्तर पर बोनस अंक',
        'कठिनाई आपके स्तर के अनुसार',
        'विषयों में प्रगति ट्रैक करें',
      ],
      targetRoute: '/quiz',
    ),
    'flow-free': GameIntroData(
      id: 'flow-free',
      title: 'FLOW FREE',
      titleBn: 'ফ্লো ফ্রি',
      titleHi: 'फ्लो फ्री',
      tagline: 'Connect colors. Fill the grid.',
      taglineBn: 'রঙ সংযোগ করুন। গ্রিড পূরণ করুন।',
      taglineHi: 'रंग जोड़ें। ग्रिड भरें।',
      icon: Icons.water_drop_rounded,
      accentColor: Color(0xFF00E5FF),
      secondaryColor: Color(0xFF0091EA),
      brainBenefit:
          'Trains spatial reasoning and path planning. Connecting color pairs without crossing paths strengthens your parietal cortex — the brain region responsible for spatial awareness, logical sequencing, and multi-step planning.',
      brainBenefitBn:
          'স্থানিক যুক্তি ও পথ পরিকল্পনা প্রশিক্ষণ দেয়। রঙের জোড়া ছাড়াই পথ সংযোগ করা প্যারিটাল কর্টেক্সকে শক্তিশালী করে।',
      brainBenefitHi:
          'स्थानिक तर्क और पथ योजना का प्रशिक्षण करता है। रंग जोड़ों को बिना क्रॉस किए जोड़ना पैरिएटल कॉर्टेक्स को मजबूत करता है।',
      rules: [
        'Draw paths to connect matching colored dots',
        'Paths cannot cross each other',
        'Fill every cell in the grid',
        'Grids get larger with more colors',
        'Fewer moves earn higher scores',
      ],
      rulesBn: [
        'মিলিয়ে রঙের ডট সংযোগ করতে পথ আঁকুন',
        'পথ পরস্পরকে ছুঁতে পারে না',
        'গ্রিডের প্রতিটি কোষ পূরণ করুন',
        'গ্রিড বড় হলে আরও রঙ থাকে',
        'কম মুভে বেশি স্কোর',
      ],
      rulesHi: [
        'मैचिंग रंग के डॉट्स जोड़ने के लिए पथ खींचें',
        'पथ एक-दूसरे को छू नहीं सकते',
        'ग्रिड की हर सेल भरें',
        'ग्रिड बड़ा होने पर ज़्यादा रंग होते हैं',
        'कम चालों में ज़्यादा स्कोर',
      ],
      targetRoute: '/flow-free',
      showOrbitingDots: true,
    ),
    'one-line': GameIntroData(
      id: 'one-line',
      title: 'ONE LINE',
      titleBn: 'ওয়ান লাইন',
      titleHi: 'वन लाइन',
      tagline: 'Draw the impossible shape.',
      taglineBn: 'অসম্ভব আকৃতি আঁকুন।',
      taglineHi: 'असंभव आकृति बनाएँ।',
      icon: Icons.draw_rounded,
      accentColor: Color(0xFFE040FB),
      secondaryColor: Color(0xFFAA00FF),
      brainBenefit:
          'Develops graph thinking and spatial awareness. Tracing complex shapes with a single continuous stroke engages your prefrontal cortex and strengthens problem-solving through Euler path reasoning.',
      brainBenefitBn:
          'গ্রাফ চিন্তা ও স্থানিক সচেতনতা বিকাশ করে। একটি ধারাবাহিক স্ট্রোকে জটিল আকৃতি ট্রেস করা প্রিফ্রন্টাল কর্টেক্সকে সক্রিয় করে।',
      brainBenefitHi:
          'ग्राफ सोच और स्थानिक जागरूकता विकसित करता है। एक निरंतर स्ट्रोक में जटिल आकृतियाँ बनाना प्रीफ्रंटल कॉर्टेक्स को सक्रिय करता है।',
      rules: [
        'Trace the shape with a single continuous stroke',
        'Never trace the same line twice',
        'Lift your finger anytime — your progress waits',
        'Stuck? Undo freely, there is no fail state',
        'Shapes get more complex each level',
      ],
      rulesBn: [
        'একটি ধারাবাহিক স্ট্রোকে আকৃতি ট্রেস করুন',
        'প্রতিটি প্রান্ত ঠিক একবার পার হতে হবে',
        'যেকোনো সময়ে আঙুল তুলুন — অগ্রগতি অটুট থাকবে',
        'আটকে গেলে? নির্দ্বিধায় আনডু করুন, ব্যর্থতা নেই',
        'প্রতিটি লেভেলে জটিল আকৃতি',
      ],
      rulesHi: [
        'एक निरंतर स्ट्रोक में आकृति ट्रेस करें',
        'हर किनारा ठीक एक बार पार किया जाना चाहिए',
        'कभी भी उंगली उठाएँ — प्रगति सुरक्षित रहती है',
        'फँस गए? बेझिझक अनडू करें, कोई विफलता नहीं',
        'हर लेवल पर जटिल आकृतियाँ',
      ],
      targetRoute: '/one-line',
      showOrbitingDots: true,
    ),
  };
}
