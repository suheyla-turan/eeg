import '../models/text_content.dart';
import '../models/text_quiz_question.dart';

/// Uygulamaya gömülü okuma metinleri.
///
/// 3 metin × ~3 dk okuma ≈ 10 dakikalık metin oturumu.
/// Yeni metin eklemek için bu listeye bir [LocalTextEntry] ekleyin.
const List<LocalTextEntry> kLocalTexts = [
  LocalTextEntry(
    id: 'text_01',
    title: 'Karar Verme Süreçlerinde İnsan Psikolojisi',
    difficulty: 'kolay',
    estimatedDuration: 180,
    content: '''
İnsanlar gün içinde farkında olmadan çok sayıda karar verir. Sabah hangi saatte uyanacağımıza, kahvaltıda ne yiyeceğimize veya hangi yolu kullanarak gideceğimize kadar birçok seçim yaparız. Bu kararların bazıları yalnızca birkaç saniye içinde alınırken, bazıları uzun süre düşünmeyi ve farklı seçenekleri değerlendirmeyi gerektirir. Karar verme süreci yalnızca mantıklı düşünmeye dayanmaz; geçmiş deneyimler, duygular, çevresel koşullar ve içinde bulunulan durum da bu süreci etkileyebilir.

Psikoloji alanında yapılan araştırmalar, insanların her zaman tamamen rasyonel kararlar vermediğini göstermektedir. Özellikle zaman baskısı altında veya yoğun stres yaşandığında insanlar, ayrıntılı değerlendirme yapmak yerine daha önce benzer durumlarda işe yarayan yöntemleri tercih edebilirler. Bu durum günlük yaşamda zaman kazandırsa da bazı durumlarda yanlış kararların alınmasına neden olabilir. Örneğin alışveriş yaparken gerçekten ihtiyaç duyulmayan bir ürünün yalnızca indirimde olduğu için satın alınması buna örnek gösterilebilir. Bu tür kararlar çoğu zaman anlık duyguların etkisiyle verilir.

Karar verme sürecinde alışkanlıkların da önemli bir etkisi vardır. Sürekli tekrar edilen davranışlar zamanla otomatik hale gelir ve kişi bu davranışları gerçekleştirirken uzun süre düşünme ihtiyacı hissetmez. Her gün aynı saatte uyanan veya işe giderken sürekli aynı yolu kullanan kişiler bunun farkında bile olmayabilir. Alışkanlıklar günlük yaşamı kolaylaştırsa da bazen farklı seçeneklerin değerlendirilmesini engelleyebilir. Bu nedenle önemli kararlar alınırken yalnızca alışkanlıklara güvenmek yerine mevcut koşulların yeniden gözden geçirilmesi yararlı olabilir.

Kararları etkileyen bir diğer unsur ise çevredir. İnsanlar çoğu zaman ailelerinin, arkadaşlarının veya içinde bulundukları toplumun görüşlerinden etkilenebilirler. Özellikle grup hâlinde alınan kararlarda bireyler, kendi düşüncelerini dile getirmek yerine çoğunluğun fikrine uyma eğiliminde olabilir. Bu durum sosyal kabul görme isteğinden kaynaklanabilir. Ancak her zaman çoğunluğun doğru kararı verdiği söylenemez. Farklı görüşleri değerlendirebilmek ve gerektiğinde kendi düşüncesini savunabilmek daha sağlıklı kararlar alınmasına katkı sağlayabilir.

Son yıllarda teknolojinin gelişmesiyle birlikte insanlar karar verirken dijital araçlardan da yararlanmaya başlamıştır. Harita uygulamalarının önerdiği rotalar, alışveriş sitelerinin ürün tavsiyeleri veya sosyal medya platformlarının sunduğu içerikler seçimlerimizi doğrudan ya da dolaylı olarak etkileyebilmektedir. Bu öneriler çoğu zaman kullanıcıların önceki davranışlarına göre oluşturulmaktadır. Her ne kadar bu sistemler karar vermeyi kolaylaştırsa da bireyin farklı seçenekleri kendi değerlendirmesi önemini korumaktadır.

Sonuç olarak karar verme, yalnızca doğru veya yanlış seçeneklerden birini seçmekten ibaret değildir. Bu süreç; düşünme biçimi, duygular, alışkanlıklar, sosyal çevre ve teknolojik etkenlerin birlikte rol oynadığı karmaşık bir yapıya sahiptir. Daha bilinçli kararlar verebilmek için seçenekleri karşılaştırmak, acele etmemek ve yalnızca ilk izlenime göre hareket etmemek faydalı olabilir.
''',
    questions: [
      TextQuizQuestion(
        questionId: 'text_01_q1',
        prompt:
            'Metne göre aşağıdakilerden hangisi insanların kararlarını etkileyen unsurlardan biri olarak doğrudan belirtilmiştir?',
        choices: [
          'Hava sıcaklığı',
          'Geçmiş deneyimler',
          'Yaşanılan şehir',
          'Eğitim süresi',
        ],
        correctIndex: 1,
      ),
      TextQuizQuestion(
        questionId: 'text_01_q2',
        prompt:
            'Metne göre insanlar zaman baskısı altında neden daha hızlı karar verme eğiliminde olabilir?',
        choices: [
          'Her zaman en doğru seçeneği buldukları için',
          'Çevrelerindeki insanların baskısından çekindikleri için',
          'Daha önce işe yarayan yöntemleri tercih ettikleri için',
          'Teknolojik araçlara güvenmedikleri için',
        ],
        correctIndex: 2,
      ),
      TextQuizQuestion(
        questionId: 'text_01_q3',
        prompt:
            'Aşağıdaki durumlardan hangisi metinde anlatılan karar verme sürecine en uygun örnektir?',
        choices: [
          'Deniz, arkadaşları önerdiği için hiç araştırma yapmadan bir telefonu satın almıştır.',
          'Elif, harita uygulamasının önerisini incelemiş, trafik durumunu da değerlendirerek farklı rotaları karşılaştırdıktan sonra kendi kararını vermiştir.',
          'Mehmet, her gün aynı saatte uyandığı için alarm kurmamaktadır.',
          'Ayşe, markette gördüğü ilk ürünü fiyatına bakmadan sepete eklemiştir.',
        ],
        correctIndex: 1,
      ),
    ],
  ),
  LocalTextEntry(
    id: 'text_02',
    title: 'Zaman Yönetimi ve Üretkenlik',
    difficulty: 'orta',
    estimatedDuration: 180,
    content: '''
Günümüzde birçok insanın ortak şikâyetlerinden biri, yapmak istediği işlere yeterince zaman ayıramamaktır. Çoğu kişi günün sonunda planladığı görevlerin bir kısmını tamamlayamadığını düşünür. Bunun temel nedeni her zaman zamanın yetersiz olması değildir. Çoğu zaman mevcut zamanı nasıl kullandığımız, ne kadar zamana sahip olduğumuzdan daha belirleyicidir. Bu nedenle zaman yönetimi, yalnızca bir plan hazırlamak değil, aynı zamanda öncelikleri doğru belirlemek ve dikkat dağıtıcı unsurları kontrol edebilmek anlamına gelir.

İnsanlar genellikle gün içinde en önemli işleri yapmak yerine daha kısa sürede tamamlanabilecek veya daha kolay görünen görevleri seçme eğilimindedir. Bu durum kişiye geçici bir başarı hissi verse de gerçekten önemli işlerin sürekli ertelenmesine neden olabilir. Özellikle teslim tarihi yaklaşan görevlerin son ana bırakılması, hem stres düzeyini artırır hem de yapılan işin kalitesini olumsuz etkileyebilir. Bu nedenle birçok uzman, büyük işleri küçük parçalara ayırarak düzenli şekilde ilerlemenin daha verimli olduğunu belirtmektedir.

Teknolojik gelişmeler çalışma hayatını kolaylaştırırken aynı zamanda yeni dikkat dağıtıcı unsurları da beraberinde getirmiştir. Telefon bildirimleri, sosyal medya uygulamaları veya sık sık kontrol edilen mesajlar, çalışma süresinin fark edilmeden bölünmesine neden olabilir. Kısa görünen bu kesintiler tek başına önemli görünmese de günün sonunda toplam çalışma süresini ciddi şekilde azaltabilir. Bu nedenle bazı kişiler çalışırken bildirimleri kapatmayı veya belirli aralıklarla mola vermeyi tercih etmektedir.

Verimli çalışmanın önemli unsurlarından biri de dinlenmeye zaman ayırmaktır. Uzun süre aralıksız çalışmak her zaman daha fazla iş üretildiği anlamına gelmez. Araştırmalar, belirli aralıklarla verilen kısa molaların dikkatin yeniden toplanmasına yardımcı olabileceğini göstermektedir. Bunun yanında düzenli uyku, yeterli su tüketimi ve fiziksel hareket de zihinsel performansı destekleyen faktörler arasında yer almaktadır. Dolayısıyla üretkenlik yalnızca çalışma süresini artırmakla değil, çalışma kalitesini koruyabilmekle de ilgilidir.

Zaman yönetimi konusunda herkes için geçerli tek bir yöntem bulunmamaktadır. Bazı kişiler ayrıntılı günlük planlarla daha verimli çalışırken, bazıları yalnızca temel hedeflerini belirleyerek daha rahat ilerleyebilir. Önemli olan seçilen yöntemin kişinin yaşam düzenine uygun olması ve uzun süre sürdürülebilmesidir. Sürekli değiştirilen planlar yerine uygulanabilir alışkanlıklar oluşturmak, zaman içinde daha kalıcı sonuçlar sağlayabilir.

Sonuç olarak zaman yönetimi, günü mümkün olduğunca fazla işle doldurmak anlamına gelmez. Asıl amaç, yapılması gereken işleri önem sırasına göre planlamak, dikkati gereksiz yere bölen etkenleri azaltmak ve dinlenmeye de yer veren dengeli bir çalışma düzeni oluşturmaktır. Böyle bir yaklaşım hem üretkenliği artırabilir hem de uzun vadede tükenmişlik hissinin azalmasına katkı sağlayabilir.
''',
    questions: [
      TextQuizQuestion(
        questionId: 'text_02_q1',
        prompt:
            'Metne göre aşağıdakilerden hangisi zaman yönetiminin önemli unsurlarından biri olarak belirtilmiştir?',
        choices: [
          'Gün içindeki tüm boş zamanı çalışarak geçirmek',
          'Öncelikleri doğru belirlemek',
          'Aynı anda birden fazla işe başlamak',
          'Mümkün olduğunca kısa sürede çok iş yapmak',
        ],
        correctIndex: 1,
      ),
      TextQuizQuestion(
        questionId: 'text_02_q2',
        prompt:
            'Metne göre telefon bildirimleri ve sosyal medya kullanımının çalışma üzerindeki temel etkisi nedir?',
        choices: [
          'Çalışmayı tamamen engellemesi',
          'Daha uzun süre odaklanmayı sağlaması',
          'Çalışma süresini fark edilmeden bölmesi ve verimliliği azaltması',
          'Daha hızlı karar vermeye yardımcı olması',
        ],
        correctIndex: 2,
      ),
      TextQuizQuestion(
        questionId: 'text_02_q3',
        prompt:
            'Aşağıdaki kişilerden hangisinin çalışma biçimi metinde önerilen zaman yönetimi anlayışıyla en fazla örtüşmektedir?',
        choices: [
          'Burak, önemli projeyi sürekli erteleyip yalnızca kısa ve kolay işleri tamamlamaktadır.',
          'Ayşe, gün boyunca hiç mola vermeden çalışmayı tercih etmektedir.',
          'Zeynep, büyük görevleri küçük parçalara ayırmakta, çalışırken bildirimlerini kapatmakta ve kısa molalar vermektedir.',
          'Emre, günlük plan hazırlamak yerine yapılacak işleri rastgele seçerek ilerlemektedir.',
        ],
        correctIndex: 2,
      ),
    ],
  ),
  LocalTextEntry(
    id: 'text_03',
    title: 'Farklı Kültürlerle İletişimin Önemi',
    difficulty: 'orta',
    estimatedDuration: 180,
    content: '''
Küreselleşmenin hız kazanmasıyla birlikte insanlar geçmişe kıyasla çok daha fazla farklı kültürle etkileşim kurmaktadır. Eğitim, iş hayatı, turizm ve dijital iletişim araçları sayesinde farklı ülkelerde yaşayan bireylerle iletişim kurmak artık günlük yaşamın doğal bir parçası hâline gelmiştir. Bu durum yalnızca yeni insanlarla tanışmayı değil, aynı zamanda farklı düşünce biçimlerini, yaşam tarzlarını ve değerleri anlamayı da gerekli kılmaktadır.

Kültür; bir toplumun dili, gelenekleri, inançları, yaşam alışkanlıkları ve davranış biçimlerinin bütününü ifade eder. Aynı olaya farklı toplumların farklı anlamlar yüklemesi oldukça doğaldır. Bu nedenle başka bir kültürden gelen bir kişinin davranışını değerlendirirken yalnızca kendi bakış açımızı kullanmak yanlış anlaşılmalara neden olabilir. Etkili iletişim kurabilmek için farklılıkları yargılamadan önce anlamaya çalışmak önemlidir.

İnsanlar genellikle kendilerine benzeyen kişilerle iletişim kurarken daha rahat hissederler. Ancak farklı kültürlerden bireylerle kurulan iletişim, kişilerin olaylara farklı açılardan bakabilmesine yardımcı olabilir. Örneğin bir ekip çalışmasında farklı ülkelerden gelen insanların bir araya gelmesi, aynı probleme birbirinden farklı çözüm önerileri sunulmasını sağlayabilir. Bu çeşitlilik, doğru yönetildiğinde daha yaratıcı ve etkili sonuçlar ortaya çıkarabilir.

Farklı kültürlerle iletişim kurarken karşılaşılan en büyük zorluklardan biri önyargılardır. İnsanlar bazen yeterli bilgiye sahip olmadan belirli toplumlar hakkında genellemeler yapabilir. Bu durum hem iletişimi zorlaştırabilir hem de karşılıklı güvenin oluşmasını engelleyebilir. Oysa önyargılar yerine merak duygusuyla yaklaşmak ve karşı tarafı dinlemeye istekli olmak daha sağlıklı ilişkiler kurulmasına katkı sağlayabilir.

Teknolojinin gelişmesiyle birlikte kültürler arasındaki etkileşim daha da artmıştır. Sosyal medya, çevrim içi eğitim platformları ve uluslararası çalışma ortamları sayesinde insanlar dünyanın farklı bölgelerindeki kişilerle kolayca iletişim kurabilmektedir. Bununla birlikte dijital iletişimde beden dili, ses tonu veya yüz ifadeleri her zaman tam olarak aktarılamadığı için yanlış anlaşılmalar yaşanabilmektedir. Bu nedenle yazılı iletişimde kullanılan ifadelerin açık ve saygılı olması büyük önem taşır.

Sonuç olarak farklı kültürlerle etkili iletişim kurabilmek yalnızca yabancı dil bilmekten ibaret değildir. Empati kurabilmek, önyargılardan uzak durmak, farklı bakış açılarını anlamaya istekli olmak ve iletişim sırasında karşılıklı saygıyı koruyabilmek de bu sürecin önemli parçalarıdır. Günümüzde bireylerin bu becerileri geliştirmesi hem sosyal yaşamda hem de eğitim ve iş hayatında önemli avantajlar sağlayabilir.
''',
    questions: [
      TextQuizQuestion(
        questionId: 'text_03_q1',
        prompt: 'Metne göre kültür kavramı aşağıdakilerden hangisini kapsamaz?',
        choices: [
          'Bir toplumun geleneklerini',
          'Bir toplumun yaşam alışkanlıklarını',
          'Bir toplumun dilini',
          'Bir bireyin günlük ruh hâlini',
        ],
        correctIndex: 3,
      ),
      TextQuizQuestion(
        questionId: 'text_03_q2',
        prompt:
            'Metne göre farklı kültürlerden insanların aynı ekipte çalışmasının önemli avantajlarından biri aşağıdakilerden hangisidir?',
        choices: [
          'Kararların daha hızlı alınması',
          'Aynı bakış açısının güçlenmesi',
          'Problemlere farklı çözüm önerileri geliştirilebilmesi',
          'İletişim ihtiyacının azalması',
        ],
        correctIndex: 2,
      ),
      TextQuizQuestion(
        questionId: 'text_03_q3',
        prompt:
            'Aşağıdaki durumlardan hangisi metinde önerilen iletişim anlayışına en uygun örnektir?',
        choices: [
          'Selin, farklı bir ülkeden gelen arkadaşının davranışını anlamadan eleştirmektedir.',
          'Ahmet, farklı kültürlerden insanlarla çalışırken yalnızca kendi alışkanlıklarının doğru olduğunu düşünmektedir.',
          'Merve, çevrim içi bir proje grubunda farklı görüşleri dikkatle dinlemekte, anlamadığı noktaları saygılı bir şekilde sormakta ve ortak çözüm geliştirmeye çalışmaktadır.',
          'Can, yanlış anlaşılma yaşamamak için farklı kültürlerden insanlarla iletişim kurmaktan kaçınmaktadır.',
        ],
        correctIndex: 2,
      ),
    ],
  ),
];

class LocalTextEntry {
  const LocalTextEntry({
    required this.id,
    required this.title,
    required this.content,
    this.difficulty = '',
    this.estimatedDuration = 0,
    this.active = true,
    this.questions = const [],
  });

  final String id;
  final String title;
  final String content;
  final String difficulty;
  final int estimatedDuration;
  final bool active;
  final List<TextQuizQuestion> questions;

  TextContent toTextContent() {
    return TextContent(
      textId: id,
      title: title,
      content: content.trim(),
      difficulty: difficulty,
      estimatedDuration: estimatedDuration,
      active: active,
      createdAt: DateTime(2026, 1, 1),
      questions: questions,
    );
  }
}
