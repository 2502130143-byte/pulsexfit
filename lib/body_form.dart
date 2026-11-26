import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'services.dart';
import 'ui.dart';
import 'shell.dart';

/// Entra a la app: si falta el formulario de datos físicos, lo muestra primero.
void goHome(BuildContext c, {int? t}) {
  if (t != null) tab.value = t;
  S.unlocked = true;
  goRoot(c, S.hasBody ? const Shell() : const BodyFormPage());
}

/// Formulario inicial: sexo, peso, talla (estatura), edad y mayor reto.
class BodyFormPage extends StatefulWidget {
  final bool edit;
  const BodyFormPage({super.key, this.edit = false});
  @override
  State<BodyFormPage> createState() => _BodyFormPageState();
}

class _BodyFormPageState extends State<BodyFormPage> {
  late String sex = S.sex;
  late final age = TextEditingController(text: S.age > 0 ? '${S.age}' : '');
  late final weight = TextEditingController(text: S.weight > 0 ? S.weight.toStringAsFixed(S.weight % 1 == 0 ? 0 : 1) : '');
  late final height = TextEditingController(text: S.height > 0 ? '${S.height}' : '');
  late final other = TextEditingController();
  late String reto = S.challenge;
  bool busy = false;

  static const retos = [
    (Icons.monitor_weight_outlined, 'Bajar de peso'),
    (Icons.directions_run, 'Correr 5 km'),
    (Icons.event_repeat, 'Ser constante'),
    (Icons.bolt, 'Ganar resistencia'),
    (Icons.favorite_border, 'Mejorar mi salud'),
    (Icons.edit_note, 'Otro'),
  ];

  @override
  void initState() {
    super.initState();
    if (reto.isNotEmpty && !retos.any((r) => r.$2 == reto)) {
      other.text = reto;
      reto = 'Otro';
    }
  }

  Future<void> save() async {
    final a = int.tryParse(age.text.trim());
    final w = double.tryParse(weight.text.trim().replaceAll(',', '.'));
    final h = int.tryParse(height.text.trim());
    final r = reto == 'Otro' ? other.text.trim() : reto;
    if (sex.isEmpty) return snack(context, 'Selecciona tu sexo');
    if (a == null || a < 10 || a > 100) return snack(context, 'Escribe una edad válida (10 a 100 años)');
    if (w == null || w < 25 || w > 300) return snack(context, 'Escribe un peso válido en kg (25 a 300)');
    if (h == null || h < 100 || h > 250) return snack(context, 'Escribe tu talla en centímetros (100 a 250)');
    if (r.isEmpty) return snack(context, reto == 'Otro' ? 'Escribe cuál es tu mayor reto' : 'Elige tu mayor reto');
    setState(() => busy = true);
    await S.saveBody(sex: sex, weight: w, height: h, age: a, challenge: r);
    if (!mounted) return;
    setState(() => busy = false);
    if (widget.edit) {
      snack(context, 'Datos actualizados');
      Navigator.pop(context);
    } else {
      snack(context, '¡Listo, ${S.firstName}! Tu plan está personalizado');
      goRoot(context, const Shell());
    }
  }

  Widget title(IconData i, String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(children: [glowIcon(i, 26), const SizedBox(width: 10), Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))]),
  );

  Widget sexBtn(String t, IconData i) {
    final on = sex == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => sex = t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: on ? const LinearGradient(colors: [Color(0xFF5B0FB8), purple, Color(0xFF1A6BFF)]) : null,
            color: on ? null : card2,
            border: Border.all(color: on ? cyan : purple.withOpacity(.45), width: on ? 1.8 : 1),
            boxShadow: on ? [BoxShadow(color: purple.withOpacity(.6), blurRadius: 16)] : null,
          ),
          child: Column(children: [
            on ? glowIcon(i, 34, c: Colors.white) : Icon(i, size: 34, color: soft),
            const SizedBox(height: 4),
            Text(t, style: TextStyle(fontSize: 16, fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  Widget numField(String label, String unit, IconData i, TextEditingController ctl, {bool dec = false}) => Expanded(
    child: Glass(
      r: 20,
      glow: false,
      p: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(i, color: cyan, size: 18), const SizedBox(width: 6), Flexible(child: FittedBox(child: Text(label, style: const TextStyle(color: soft, fontSize: 13))))]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: ctl,
              keyboardType: TextInputType.numberWithOptions(decimal: dec),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(dec ? r'[0-9.,]' : r'[0-9]')), LengthLimitingTextInputFormatter(dec ? 5 : 3)],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              cursorColor: cyan,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '--', hintStyle: TextStyle(color: soft)),
            ),
          ),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(unit, style: const TextStyle(color: soft))),
        ]),
      ]),
    ),
  );

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
          Row(children: [
            if (widget.edit) IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(c)) else const SizedBox(width: 48),
            const Expanded(child: Center(child: PulseLogo(size: 34))),
            const SizedBox(width: 48),
          ]),
          const SizedBox(height: 8),
          const Center(child: PulseLine(width: 180, height: 32)),
          Center(child: GradText(widget.edit ? 'Mis datos físicos' : 'Cuéntanos de ti', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic), colors: const [Colors.white, cyan])),
          const SizedBox(height: 4),
          const Center(child: Text('Con estos datos calculamos tu distancia,\ncalorías y tu plan personalizado.', textAlign: TextAlign.center, style: TextStyle(color: soft, fontSize: 15))),
          title(Icons.wc, 'Sexo'),
          Row(children: [sexBtn('Hombre', Icons.male), const SizedBox(width: 10), sexBtn('Mujer', Icons.female), const SizedBox(width: 10), sexBtn('Otro', Icons.transgender)]),
          title(Icons.accessibility_new, 'Tu cuerpo'),
          Row(children: [
            numField('Edad', 'años', Icons.cake_outlined, age),
            const SizedBox(width: 8),
            numField('Peso', 'kg', Icons.monitor_weight_outlined, weight, dec: true),
            const SizedBox(width: 8),
            numField('Talla', 'cm', Icons.height, height),
          ]),
          ListenableBuilder(
            listenable: Listenable.merge([weight, height]),
            builder: (_, __) {
              final w = double.tryParse(weight.text.replaceAll(',', '.')) ?? 0, h = int.tryParse(height.text) ?? 0;
              if (w < 25 || h < 100) return const SizedBox(height: 4);
              final imc = w / ((h / 100) * (h / 100));
              final (lbl, col) = imc < 18.5 ? ('Bajo peso', cyan) : (imc < 25 ? ('Saludable', green) : (imc < 30 ? ('Sobrepeso', orange) : ('Obesidad', red)));
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Glass(
                  r: 16,
                  glow: false,
                  p: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    glowIcon(Icons.speed, 24, c: col),
                    const SizedBox(width: 10),
                    Text('IMC ${imc.toStringAsFixed(1)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Dot(lbl, col: col),
                  ]),
                ),
              );
            },
          ),
          title(Icons.emoji_events_outlined, '¿Cuál es tu mayor reto?'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.9,
            children: [
              for (final r in retos)
                GestureDetector(
                  onTap: () => setState(() => reto = r.$2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: reto == r.$2 ? const Color(0xFF16301A) : card2,
                      border: Border.all(color: reto == r.$2 ? lime : purple.withOpacity(.45), width: reto == r.$2 ? 1.8 : 1),
                      boxShadow: reto == r.$2 ? [BoxShadow(color: lime.withOpacity(.4), blurRadius: 12)] : null,
                    ),
                    child: Row(children: [
                      Icon(r.$1, color: reto == r.$2 ? lime : cyan, size: 22),
                      const SizedBox(width: 8),
                      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(r.$2, style: TextStyle(fontSize: 15, color: reto == r.$2 ? lime : Colors.white)))),
                    ]),
                  ),
                ),
            ],
          ),
          if (reto == 'Otro') ...[
            const SizedBox(height: 10),
            NeonField('Escribe tu mayor reto', Icons.flag_outlined, other, action: TextInputAction.done),
          ],
          const SizedBox(height: 26),
          GradBtn(widget.edit ? 'Guardar cambios' : 'Guardar y continuar', save, icon: Icons.check_circle_outline, busy: busy),
        ]),
      ),
    ),
  );
}
