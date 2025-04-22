# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

1.upto(50) do |i|
  User.create(
    first_name: "user",
    last_name: "#{i}",
    email: "user@#{i}",
    password: "user@#{i}",
    password_confirmation: "user@#{i}"
  )
end