package it.constantinoit.promoproject.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectWriter;
import it.constantinoit.promoproject.kafka.producer.MessageProducer;
import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.service.ProspectService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class ProspectController {

    private static Logger LOG = LoggerFactory.getLogger(ProspectController.class);

    @Autowired
    private ProspectService prospectService;

    @Autowired
    private MessageProducer messageProducer;

    @GetMapping(value = "/listProspects", produces = "application/json")
    public List<Prospect> listProspects() {
        return prospectService.listProspects();
    }

    @PostMapping(value = "/sendKafkaMessage", consumes = "application/json", produces = "application/json")
    public boolean sendMessage(@RequestBody Prospect target) throws JsonProcessingException {
        ObjectWriter ow = new ObjectMapper().writer().withDefaultPrettyPrinter();
        String json = ow.writeValueAsString(target);
        messageProducer.sendMessage("promoproject", json);
        LOG.info("Send message:  {}", json);
        return Boolean.TRUE;
    }

}