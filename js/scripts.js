$(document).ready(function(){
    $('#nav').onePageNav();

    $('a[href^="http"]').attr('target','_blank');
    
    $('.toggle').click(function(){
        $('.overview').toggleClass('open');
    });
});
