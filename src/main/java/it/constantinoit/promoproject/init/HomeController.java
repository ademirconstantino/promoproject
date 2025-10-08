package it.constantinoit.promoproject.init;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("titulo", "Constantino IT PromoProject");
        model.addAttribute("mensagem", "Copyright (C) 2022-2025");
        return "index";
    }
}