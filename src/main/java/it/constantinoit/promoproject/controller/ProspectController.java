package it.constantinoit.promoproject.controller;

import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.service.ProspectService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class ProspectController {

    private static Logger logger = LoggerFactory.getLogger(ProspectController.class);

    @Autowired
    private ProspectService prospectService;

    @GetMapping(value = "/listProspects", produces = "application/json")
    public List<Prospect> listProspects() {
        return prospectService.listProspects();
    }

}