class User < ActiveRecord::Base
	belongs_to :referrer, class_name: "User", foreign_key: :referrer_id
    has_many :referrals, class_name: "User", foreign_key: :referrer_id

    validates :email, uniqueness: true, format: { with: Devise::email_regexp, message: "Invalid email format." }, presence: true
    validates :ip_address, presence: true #, uniqueness: true
    validate :ip_address_blocking_check

    before_create :set_referral_code
    after_create :welcome_email

    def prize
    	Prize.where(number_of_referrals: 0..number_of_referrals).order("number_of_referrals asc").last
    end

    def progress
        unit = prize ? 1.fdiv(Prize.all.count) :1.fdiv(2 * Prize.all.count)
        targets = Prize.all.order("number_of_referrals asc").pluck(:number_of_referrals)
        base = 0

        unless prize
            return unit * (number_of_referrals.fdiv(targets[0])) 
        end

        targets.each_with_index do |value, index|  
            if number_of_referrals >= value && value > 0
                base += unit 
            elsif index > 0
                base += unit * (number_of_referrals - targets[index - 1]).fdiv(value - targets[index - 1])
                break
            end
        end

        base -= unit.fdiv(2)

        return base
    end

    def achieved prize
        prize.number_of_referrals <= number_of_referrals
    end


    def prize_name
        prize ? prize.name : nil
    end

    def number_of_referrals
        referrals.count
    end

    def user_url(root_url)
        root_url + "users/" + referral_code
    end

    def referral_url(root_url)
        root_url + "?ref=" + referral_code
    end

    def self.as_csv
        attributes = [:id, :created_at, :email, :ip_address, :referrer_id, :referral_code, :number_of_referrals, :prize_name]

        CSV.generate do |csv|
            csv << attributes
            all.each do |item|
                raw = []
                attributes.each do |attribute|
                    raw << item.send(attribute)
                end
                csv << raw
            end
        end
    end

    private

    def set_referral_code
    	self.referral_code = generate_referral_code
    end

    def generate_referral_code
	    loop do
	      code = SecureRandom.hex(5)
	      break code unless self.class.where(referral_code: code).exists?
	    end
    end

    def welcome_email
        UserMailer.delay.sign_up_email(self)
    end

    def ip_address_blocking_check
        errors.add(:ip_address, " can't add email more than " + Setting.blocking_count.to_s) unless 
            self.class.where(ip_address: self.ip_address).count < Setting.blocking_count
    end
end