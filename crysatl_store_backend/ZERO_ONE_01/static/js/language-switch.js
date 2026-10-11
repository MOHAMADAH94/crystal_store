// const translations = {
//     "en": {

        

//     },
//     "ar": {
//         
        

//     },
//     "tr": {
//         
//     }
// };

// // دالة لتغيير اللغة
// function changeLanguage(lang) {
//     // تخزين اللغة في LocalStorage
//     localStorage.setItem('selectedLanguage', lang);
    
//     // تغيير النصوص بناءً على اللغة المحددة
//     document.querySelectorAll('[data-translate]').forEach(element => {
//         const key = element.getAttribute('data-translate');
//         element.textContent = translations[lang][key];
//     });
// }

// // دالة لتحميل اللغة من LocalStorage عند تحميل الصفحة
// function loadLanguage() {
//     const savedLang = localStorage.getItem('selectedLanguage') || 'en'; // إذا لم يتم العثور على لغة، استخدم الإنجليزية بشكل افتراضي
//     changeLanguage(savedLang);  // تحميل اللغة المحفوظة
// }

// // استدعاء دالة تحميل اللغة عند تحميل الصفحة
// document.addEventListener('DOMContentLoaded', loadLanguage);
