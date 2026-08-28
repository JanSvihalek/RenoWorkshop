# Pravidla pro zmenšování a obfuskaci v release buildu (R8).

# ML Kit pro rozpoznávání textu odkazuje na varianty pro čínštinu,
# japonštinu, korejštinu a dévanágarí. Používáme jen latinku, takže
# tyhle knihovny v závislostech nejsou - a R8 by na chybějící třídy
# jinak build shodil.
#
# Kdyby appka někdy měla číst i jiná písma, přidají se místo tohohle
# závislosti google_mlkit_text_recognition_<jazyk>.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
