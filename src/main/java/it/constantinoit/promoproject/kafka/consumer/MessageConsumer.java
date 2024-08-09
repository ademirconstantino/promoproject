package it.constantinoit.promoproject.kafka.consumer;

import com.fasterxml.jackson.core.JsonProcessingException;
import it.constantinoit.promoproject.events.PostmailEventHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class MessageConsumer {

    @Autowired
    private PostmailEventHandler postmailEventHandler;

    private static final Logger LOG = LoggerFactory.getLogger(MessageConsumer.class);

    @KafkaListener(topics = "promoproject", groupId = "test-consumer-group")
    public void listen(String message) throws JsonProcessingException {
        LOG.info("Received message: {}", message);
        LOG.info("Sending message: {} to the EventHandler", message);
        postmailEventHandler.receiveEventPostmail(message);
    }

}