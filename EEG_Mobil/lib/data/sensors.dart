class SensorInfo {
  final String id;
  final String name;
  final String region;
  final String hemisphere;
  final String measures;
  final String function;
  final String anatomy;

  const SensorInfo({
    required this.id,
    required this.name,
    required this.region,
    required this.hemisphere,
    required this.measures,
    required this.function,
    required this.anatomy,
  });
}

/// Emotiv EPOC tarzı 14 kanallı EEG sensör seti
const List<SensorInfo> sensors = [
  SensorInfo(
    id: 'AF3',
    name: 'AF3',
    region: 'Anterior Frontal',
    hemisphere: 'Sol',
    measures: 'Ön frontal korteks aktivitesi',
    function:
        'Dikkat, karar verme ve duygusal düzenleme ile ilişkilidir. Odaklanma ve yürütücü işlevlerde rol oynar.',
    anatomy:
        'Sol anterior frontal bölgede yer alır. Prefrontal korteksin ön kısmına yakındır.',
  ),
  SensorInfo(
    id: 'F7',
    name: 'F7',
    region: 'Frontal',
    hemisphere: 'Sol',
    measures: 'Sol inferior frontal aktivite',
    function:
        'Dil üretimi, çalışma belleği ve engelleyici kontrol ile ilişkilidir. Konuşma planlamasında önemlidir.',
    anatomy: 'Sol frontal lobun alt-yan kısmında (inferior frontal) konumlanır.',
  ),
  SensorInfo(
    id: 'F3',
    name: 'F3',
    region: 'Frontal',
    hemisphere: 'Sol',
    measures: 'Sol dorsolateral prefrontal aktivite',
    function:
        'Planlama, problem çözme ve olumlu duygusal işleme ile bağlantılıdır.',
    anatomy: 'Sol frontal lobun dorsolateral prefrontal bölgesine yakındır.',
  ),
  SensorInfo(
    id: 'FC5',
    name: 'FC5',
    region: 'Frontocentral',
    hemisphere: 'Sol',
    measures: 'Sol motor / premotor aktivite',
    function:
        'Hareket planlama ve motor hazırlık sinyallerini yansıtır. El/yüz motor alanlarına yakındır.',
    anatomy:
        'Sol frontal ile santral bölge arasında, premotor korteks civarındadır.',
  ),
  SensorInfo(
    id: 'T7',
    name: 'T7',
    region: 'Temporal',
    hemisphere: 'Sol',
    measures: 'Sol temporal lob aktivitesi',
    function:
        'İşitsel işleme, dil anlama ve bellek ile ilişkilidir. Sol temporal bölge konuşma algısında kritiktir.',
    anatomy:
        'Sol temporal lob üzerindedir (eski adıyla T3). Kulak hizasına yakın yan kafa bölgesidir.',
  ),
  SensorInfo(
    id: 'P7',
    name: 'P7',
    region: 'Parietal',
    hemisphere: 'Sol',
    measures: 'Sol posterior parietal aktivite',
    function:
        'Uzamsal dikkat, görsel-uzamsal işleme ve duyusal entegrasyonda rol oynar.',
    anatomy: 'Sol parietal lobun arka-yan kısmında yer alır.',
  ),
  SensorInfo(
    id: 'O1',
    name: 'O1',
    region: 'Oksipital',
    hemisphere: 'Sol',
    measures: 'Sol görsel korteks aktivitesi',
    function:
        'Görsel algı ve görüntü işlemeyi ölçer. Gözler açık/kapalı durumlarında belirgin alfa değişimleri görülür.',
    anatomy:
        'Sol oksipital lob üzerindedir; birincil görsel korteks bölgesine yakındır.',
  ),
  SensorInfo(
    id: 'O2',
    name: 'O2',
    region: 'Oksipital',
    hemisphere: 'Sağ',
    measures: 'Sağ görsel korteks aktivitesi',
    function:
        'Görsel işleme ve uzamsal görsel analiz ile ilişkilidir. O1 ile birlikte oksipital aktiviteyi tamamlar.',
    anatomy:
        'Sağ oksipital lob üzerindedir; birincil görsel korteks bölgesine yakındır.',
  ),
  SensorInfo(
    id: 'P8',
    name: 'P8',
    region: 'Parietal',
    hemisphere: 'Sağ',
    measures: 'Sağ posterior parietal aktivite',
    function:
        'Uzamsal farkındalık, dikkat yönlendirme ve duyusal entegrasyonda rol oynar.',
    anatomy: 'Sağ parietal lobun arka-yan kısmında yer alır.',
  ),
  SensorInfo(
    id: 'T8',
    name: 'T8',
    region: 'Temporal',
    hemisphere: 'Sağ',
    measures: 'Sağ temporal lob aktivitesi',
    function:
        'İşitsel işleme, prosodi (ses tonu) ve duygusal ses algısı ile ilişkilidir.',
    anatomy:
        'Sağ temporal lob üzerindedir (eski adıyla T4). Kulak hizasına yakın yan kafa bölgesidir.',
  ),
  SensorInfo(
    id: 'FC6',
    name: 'FC6',
    region: 'Frontocentral',
    hemisphere: 'Sağ',
    measures: 'Sağ motor / premotor aktivite',
    function:
        'Hareket planlama ve motor hazırlık sinyallerini yansıtır. FC5 ile simetrik konumdadır.',
    anatomy:
        'Sağ frontal ile santral bölge arasında, premotor korteks civarındadır.',
  ),
  SensorInfo(
    id: 'F4',
    name: 'F4',
    region: 'Frontal',
    hemisphere: 'Sağ',
    measures: 'Sağ dorsolateral prefrontal aktivite',
    function:
        'Duygusal düzenleme, kaçınma davranışı ve dikkat kontrolü ile bağlantılıdır.',
    anatomy: 'Sağ frontal lobun dorsolateral prefrontal bölgesine yakındır.',
  ),
  SensorInfo(
    id: 'F8',
    name: 'F8',
    region: 'Frontal',
    hemisphere: 'Sağ',
    measures: 'Sağ inferior frontal aktivite',
    function:
        'Duygusal ifade, sosyal biliş ve engelleyici kontrol süreçlerinde rol oynar.',
    anatomy: 'Sağ frontal lobun alt-yan kısmında (inferior frontal) konumlanır.',
  ),
  SensorInfo(
    id: 'AF4',
    name: 'AF4',
    region: 'Anterior Frontal',
    hemisphere: 'Sağ',
    measures: 'Ön frontal korteks aktivitesi',
    function:
        'Dikkat, karar verme ve duygusal düzenleme ile ilişkilidir. AF3 ile simetrik konumdadır.',
    anatomy:
        'Sağ anterior frontal bölgede yer alır. Prefrontal korteksin ön kısmına yakındır.',
  ),
];

final List<String> sensorIds = sensors.map((s) => s.id).toList();
