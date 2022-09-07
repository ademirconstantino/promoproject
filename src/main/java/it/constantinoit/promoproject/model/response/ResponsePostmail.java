package it.constantinoit.promoproject.model.response;

import java.util.Date;

public class ResponsePostmail {

    private String email;
    private Date deliveryDate;
    private Boolean success;

    public ResponsePostmail(ResponsePostmailBuilder responsePostmailBuilder) {
        this.email = responsePostmailBuilder.getEmail();
        this.deliveryDate = responsePostmailBuilder.getDeliveryDate();
        this.success = responsePostmailBuilder.getSuccess();
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public Date getDeliveryDate() {
        return deliveryDate;
    }

    public void setDeliveryDate(Date deliveryDate) {
        this.deliveryDate = deliveryDate;
    }

    public Boolean getSuccess() {
        return success;
    }

    public void setSuccess(Boolean success) {
        this.success = success;
    }

    public static class ResponsePostmailBuilder {
        private String email;
        private Date deliveryDate;
        private Boolean success;

        public ResponsePostmailBuilder() {}

        public ResponsePostmailBuilder withEmail(String email) {
            this.email = email;
            return this;
        }

        public ResponsePostmailBuilder withDeliveryDate(Date deliveryDate) {
            this.deliveryDate = deliveryDate;
            return this;
        }

        public ResponsePostmailBuilder withSuccess(Boolean success) {
            this.success = success;
            return this;
        }

        public ResponsePostmail build() {
            ResponsePostmail returnObject =
                    new ResponsePostmail(this);
            return returnObject;
        }

        public String getEmail() {
            return email;
        }

        public void setEmail(String email) {
            this.email = email;
        }

        public Date getDeliveryDate() {
            return deliveryDate;
        }

        public void setDeliveryDate(Date deliveryDate) {
            this.deliveryDate = deliveryDate;
        }

        public Boolean getSuccess() {
            return success;
        }

        public void setSuccess(Boolean success) {
            this.success = success;
        }
    }
}


