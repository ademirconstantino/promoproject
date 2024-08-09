package it.constantinoit.promoproject.kafka.consumer;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class MessageConsumer {

    @KafkaListener(topics = "promoproject", groupId = "test-consumer-group")
    public void listen(String message) {
        System.out.println("Received message: " + message);
    }

}